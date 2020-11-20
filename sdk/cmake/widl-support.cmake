
#idl files support
if(ARCH STREQUAL "i386")
    set(IDL_FLAGS -m32 --win32)
elseif(ARCH STREQUAL "amd64")
    set(IDL_FLAGS -m64 --win64)
else()
    set(IDL_FLAGS "")
endif()

function(add_typelib)
    get_includes(INCLUDES)
    get_defines(DEFINES)
    foreach(FILE ${ARGN})
        if(${FILE} STREQUAL "std_ole_v1.idl")
            set(IDL_FLAGS ${IDL_FLAGS} --oldtlb)
        endif()
        get_filename_component(NAME ${FILE} NAME_WE)
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.tlb
            COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -t -o ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.tlb ${CMAKE_CURRENT_SOURCE_DIR}/${FILE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${FILE} native-widl)
        list(APPEND OBJECTS ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.tlb)
    endforeach()
endfunction()

function(add_idl_headers TARGET)
    get_includes(INCLUDES)
    get_defines(DEFINES)
    foreach(FILE ${ARGN})
        get_filename_component(NAME ${FILE} NAME_WE)
        set(HEADER ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.h)
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.h
            COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -h -o ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.h ${FILE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${FILE} native-widl
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
        list(APPEND HEADERS ${HEADER})
    endforeach()
    add_custom_target(${TARGET} DEPENDS ${HEADERS})
endfunction()

function(add_rpcproxy_files)
    get_includes(INCLUDES)
    get_defines(DEFINES)

    foreach(FILE ${ARGN})
        get_filename_component(NAME ${FILE} NAME_WE)
        # Most proxy idl's have names like <proxyname>_<original>.idl
        # We use this to create a dependency from the proxy to the original idl
        string(REPLACE "_" ";" SPLIT_FILE ${FILE})
        list(LENGTH SPLIT_FILE len)
        unset(EXTRA_DEP)
        if(len STREQUAL "2")
            list(GET SPLIT_FILE 1 SPLIT_FILE)
            if(EXISTS "${REACTOS_SOURCE_DIR}/sdk/include/psdk/${SPLIT_FILE}")
                set(EXTRA_DEP ${REACTOS_SOURCE_DIR}/sdk/include/psdk/${SPLIT_FILE})
            endif()
        endif()
        list(APPEND IDLS ${FILE})
        list(APPEND IDL_DEPS ${CMAKE_CURRENT_SOURCE_DIR}/${FILE} ${EXTRA_DEP})
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_p.c ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_p.h
            COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -p -o ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_p.c -h -H ${NAME}_p.h ${FILE}
            DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/${FILE} ${EXTRA_DEP} native-widl
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endforeach()

    # Extra pass to generate dlldata
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/proxy.dlldata.c
        COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} --dlldata-only -o ${CMAKE_CURRENT_BINARY_DIR}/proxy.dlldata.c ${IDLS}
        DEPENDS ${IDL_DEPS} native-widl
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
endfunction()

function(add_rpc_files __type)
    get_includes(INCLUDES)
    get_defines(DEFINES)
    # Is it a client or server module?
    if(__type STREQUAL "server")
        set(__server_client -Oif -s -o)
        set(__suffix _s)
    elseif(__type STREQUAL "client")
        set(__server_client -Oif -c -o)
        set(__suffix _c)
    else()
        message(FATAL_ERROR "Please pass either server or client as argument to add_rpc_files")
    endif()
    foreach(FILE ${ARGN})
        get_filename_component(__name ${FILE} NAME_WE)
        set(__name ${CMAKE_CURRENT_BINARY_DIR}/${__name}${__suffix})
        add_custom_command(
            OUTPUT ${__name}.c ${__name}.h
            COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -h -H ${__name}.h ${__server_client} ${__name}.c ${FILE}
            DEPENDS ${FILE} native-widl
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endforeach()
endfunction()

function(generate_idl_iids)
    foreach(IDL_FILE ${ARGN})
        get_filename_component(FILE ${IDL_FILE} NAME)
        get_includes(INCLUDES)
        get_defines(DEFINES)
        get_filename_component(NAME ${IDL_FILE} NAME_WE)
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_i.c
            COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -u -o ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_i.c ${IDL_FILE}
            DEPENDS ${IDL_FILE_FULL} native-widl
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endforeach()
endfunction()

function(add_iid_library TARGET)
    foreach(IDL_FILE ${ARGN})
        get_filename_component(NAME ${IDL_FILE} NAME_WE)
        generate_idl_iids(${IDL_FILE})
        list(APPEND IID_SOURCES ${NAME}_i.c)
    endforeach()
    add_library(${TARGET} ${IID_SOURCES})
    add_dependencies(${TARGET} psdk)
    set_target_properties(${TARGET} PROPERTIES EXCLUDE_FROM_ALL TRUE)
endfunction()

function(add_idl_reg_script IDL_FILE)
    get_includes(INCLUDES)
    get_defines(DEFINES)
    get_filename_component(NAME ${IDL_FILE} NAME_WE)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_r.res
        COMMAND native-widl ${INCLUDES} ${DEFINES} ${IDL_FLAGS} -r -o ${CMAKE_CURRENT_BINARY_DIR}/${NAME}_r.res ${IDL_FILE}
        DEPENDS ${IDL_FILE_FULL} native-widl
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/${NAME}_r.res PROPERTIES
        GENERATED TRUE EXTERNAL_OBJECT TRUE)
endfunction()
