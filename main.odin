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

main :: proc() {
	context.logger = log.create_console_logger()
	sheet_id_data, _ := os.read_entire_file("./sheet.id")
	auth_key_data, _ := os.read_entire_file("./auth.key")
	g_sheet_id = transmute(string)sheet_id_data
	g_auth_key = transmute(string)auth_key_data

	// Create all the required files
	types_hd         := create_src_file("out/types.odin")
	def_types_hd     := create_src_file("out/defined-types.odin")
	def_functions_hd := create_src_file("out/defined-functions.odin")
	defer {
		os.close(types_hd)
		os.close(def_types_hd)
		os.close(def_functions_hd)
	}

	basic_type_data := generate_basic_types()
	log.info(basic_type_data)

	write_basic_type_file(types_hd, basic_type_data)
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

generate_defined_types :: proc(){}
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
