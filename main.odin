package main

import "core:log"
import "core:os"
import "core:fmt"
import str "core:strings"
import "core:strconv"
import http "../the-carton/dependencies/odin-http/client"
import "core:encoding/json"

g_sheet_id: string
g_auth_key: string

Type_Data :: struct {
	name, id, in_code: string
}

Def_Type_Data :: struct {
	name, given_name, type: string,
	num_fields: int,
	cell_refs: []int,
	available: bool,
}

Def_Func_Data :: struct {
	name, in_code, type, directive: string,
	input_count, exec_in_count, exec_out_count: int,
	has_output: bool,
}

create_basic_types :: proc() {
	types_hd := create_src_file("out/types.odin")
	defer os.close(types_hd)
	basic_type_data := generate_basic_types()
	log.info(basic_type_data)
	write_basic_type_file(types_hd, basic_type_data)
}

create_def_types :: proc() {
	def_types_hd     := create_src_file("out/defined-types.odin")
	defer os.close(def_types_hd)
	def_type_data := generate_defined_types()
	log.info(def_type_data)
	write_def_type_file(def_types_hd, def_type_data)
}

create_methods :: proc() {
	def_functions_hd := create_src_file("out/defined-functions.odin")
	defer os.close(def_functions_hd)
	def_func_data := generate_defined_funcs()
	log.info(def_func_data)
	write_def_func_file(def_functions_hd, def_func_data)
}

main :: proc() {
	context.logger = log.create_console_logger()
	sheet_id_data, _ := os.read_entire_file("./sheet.id")
	auth_key_data, _ := os.read_entire_file("./auth.key")
	g_sheet_id = transmute(string)sheet_id_data
	g_auth_key = transmute(string)auth_key_data

	// Create all the required files
	// create_basic_types()
	create_def_types()
	// create_methods()
}

// Create src file and add default heading
@(require_results)
create_src_file :: proc(path: string) -> os.Handle {
	hd, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != nil {
		log.fatal(err)
	}

	fmt.fprintln(hd, "package src")
	fmt.fprintln(hd, "")
	return hd
}

generate_basic_types :: proc() -> []Type_Data {
	type_data_array := make([dynamic]Type_Data)
	i := 0
	request_ok := true

	for request_ok {
		new_data: Type_Data
		new_data.name, request_ok = sheets_request("BasicTypes", i + 2, 0)
		if !request_ok do continue

		new_data.id, _ = sheets_request("BasicTypes", i + 2, 1)
		new_data.in_code, _ = sheets_request("BasicTypes", i + 2, 2)
		append(&type_data_array, new_data)
		i += 1
	}
	return type_data_array[:]
}

generate_defined_types :: proc() -> []Def_Type_Data {
	type_data_array := make([dynamic]Def_Type_Data)
	i := 0
	request_ok := true

	for request_ok {
		new_data: Def_Type_Data
		new_data.name, request_ok = sheets_request("NamedTypes", i + 2, 0)
		if !request_ok do continue
		new_data.given_name, _ = sheets_request("NamedTypes", i + 2, 1)
		new_data.type, _ = sheets_request("NamedTypes", i + 2, 2)

		available_string, _ := sheets_request("NamedTypes", i + 2, 3)
		available_int := strconv.atoi(available_string)
		if available_int == 1 {
			new_data.available = true
		} else {
			new_data.available = false
		}

		num_fields_string, _ := sheets_request("NamedTypes", i + 2, 4)
		new_data.num_fields = strconv.atoi(num_fields_string)
		if new_data.num_fields > 0 {
			cell_refs := make([dynamic]int) 
			for j in 0..<new_data.num_fields {
				new_string, _ := sheets_request("NamedTypes", i + 2, 5 + j)
				ref_as_int := strconv.atoi(new_string)
				append(&cell_refs, ref_as_int - 2)
			}
			new_data.cell_refs = cell_refs[:]
		}
		append(&type_data_array, new_data)
		i += 1
	}
	return type_data_array[:]
}

generate_defined_funcs :: proc() -> []Def_Func_Data {
	func_data_array := make([dynamic]Def_Func_Data)
	i := 0
	request_ok := true

	for request_ok {
		new_data: Def_Func_Data
		new_data.name, request_ok = sheets_request("Methods", i + 2, 0)
		if !request_ok do continue
		new_data.in_code, _ = sheets_request("Methods", i + 2, 1)
		new_data.type, _ = sheets_request("Methods", i + 2, 2)

		input_count_string, _ := sheets_request("Methods", i + 2, 3)
		new_data.input_count = strconv.atoi(input_count_string)

		exec_in_string, _ := sheets_request("Methods", i + 2, 4)
		new_data.exec_in_count = strconv.atoi(exec_in_string)

		exec_out_string, _ := sheets_request("Methods", i + 2, 5)
		new_data.exec_out_count = strconv.atoi(exec_out_string)

		has_output_string, _ := sheets_request("Methods", i + 2, 6)
		has_output := strconv.atoi(has_output_string)
		if has_output == 1 {
			new_data.has_output = true
		} else {
			new_data.has_output = false
		}

		new_data.directive, _ = sheets_request("Methods", i + 2, 7)
		append(&func_data_array, new_data)
		i += 1
	}
	return func_data_array[:]
}

sheets_request :: proc(sheet_name: string, row: int, column: int) -> (result: string, ok: bool) {
	builder: str.Builder
	b := str.builder_init(&builder)
	str.write_string(b, "https://sheets.googleapis.com/v4/spreadsheets/")
	str.write_string(b, g_sheet_id)
	str.write_string(b, "/values/")
	str.write_string(b,  sheet_name)
	str.write_string(b, "!")
	str.write_string(b, cell_changer[column])
	str.write_int(b, row)
	str.write_string(b, "?key=")
	str.write_string(b, g_auth_key)
	
	request := str.to_string(b^)
	request, _ = str.remove_all(request, "\r\n")

	res, err := http.get(request)
	if err != nil {
		log.fatal("Failed to make spreadsheet request:", err, request)
	}

	body, _, _ := http.response_body(&res)
	
	json_res, _ := json.parse_string(body.(http.Body_Plain))
	val_json, contains := json_res.(json.Object)["values"]
	if !contains {
		return "", false
	}
	return val_json.(json.Array)[0].(json.Array)[0].(json.String), true
} 

write_basic_type_file :: proc(hd: os.Handle, data: []Type_Data) {
	fmt.fprintln(hd, "Variable_Type :: enum {")
	for type in data {
		fmt.fprintln(hd, "  ", type.name, ",", sep = "")
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	
	fmt.fprintln(hd, "@(rodata)")
	fmt.fprintln(hd, "Variable_Type_Id := [?]cstring {")
	for type in data {
		if len(type.id) == 1 {
			fmt.fprintln(hd, "  \" ", type.id, "\",", sep = "")
		} else {
			fmt.fprintln(hd, "  \"", type.id, "\",", sep = "")
		}
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	fmt.fprintln(hd, "@(rodata)")
	fmt.fprintln(hd, "Variable_Type_As_String := [?]string {")
	for type in data {
		fmt.fprintln(hd, "  \"", type.in_code, "\",", sep = "")
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	fmt.fprintln(hd, "@(rodata)")
	fmt.fprintln(hd, "Variable_Type_As_CString := [?]cstring {")
	for type in data {
		fmt.fprintln(hd, "  \"", type.in_code, "\",", sep = "")
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

}

write_def_type_file :: proc(hd: os.Handle, data: []Def_Type_Data) {

	// Write Header
	fmt.fprintln(hd, "Predefined_Type :: struct {")
	fmt.fprintln(hd, "	name:   string,")
	fmt.fprintln(hd, "	type:   Variable_Type,")
	fmt.fprintln(hd, "	fields: []Predefined_Type,")
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")
	
	// Make the interface available type array
	fmt.fprintln(hd, "@(rodata)")
	fmt.fprintln(hd, "Available_Types := []Predefined_Type {")
	for type in data {
		if type.available {
			fmt.fprintln(hd, "  ", type.name, ",", sep="")
		}
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	
	// Define all the used types
	for type in data {
		fmt.fprintln(hd, type.name, " :: Predefined_Type {", sep="")
		fmt.fprintln(hd, "  type = .", type.type, ",", sep="")
		if type.given_name != "" {
			fmt.fprintln(hd, "  name = \"", type.given_name, "\",", sep="")
		}
		if type.num_fields != 0 {
			fmt.fprint(hd, "  fields = {")
			for field in type.cell_refs {
				fmt.fprint(hd, data[field].name, ", ", sep = "")
			}
			fmt.fprintln(hd, "}")
		}
		fmt.fprintln(hd, "}")
		fmt.fprintln(hd, "")
	}
}

write_def_func_file :: proc(hd: os.Handle, data: []Def_Func_Data) {
	
	fmt.fprintln(hd, "Predefined_Function :: struct {")
	fmt.fprintln(hd, "	name, directive: string,")
	fmt.fprintln(hd, "	type:            FunctionType,")
	fmt.fprintln(hd, "	has_output:      bool,")
	fmt.fprintln(hd, "	input_count, exec_in_count, exec_out_count: int,")
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	fmt.fprintln(hd, "@(rodata)")
	fmt.fprintln(hd, "Available_Functions := []Predefined_Function {")
	for func in data {
		fmt.fprintln(hd, "  ", func.name, ",", sep="")
	}
	fmt.fprintln(hd, "}")
	fmt.fprintln(hd, "")

	for func in data {
		fmt.fprintln(hd, func.name, " :: Predefined_Function {", sep="")
		fmt.fprintln(hd, "  name = \"", func.in_code, "\",", sep="")
		fmt.fprintln(hd, "  directive = \"", func.directive, "\",", sep="")
		fmt.fprintln(hd, "  type = .", func.type, ",", sep="")
		fmt.fprintln(hd, "  has_output = ", func.has_output, ",", sep = "")
		fmt.fprintln(hd, "  input_count = ", func.input_count, ",", sep="")
		fmt.fprintln(hd, "  exec_in_count = ", func.exec_in_count, ",", sep="")
		fmt.fprintln(hd, "  exec_out_count = ", func.exec_out_count, ",", sep="")
		fmt.fprintln(hd, "}")
		fmt.fprintln(hd, "")
	}
}

generate_defined_functions :: proc(){}

cell_changer := []string {
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
}
