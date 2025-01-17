#=============================================================================
# CMakeDebHelper, Copyright (C) 2013 Sebastian Kienzl
# http://knzl.de/cmake-debhelper/
# Licensed under the GPL v2, see LICENSE
#=============================================================================

# configure() .in-files to the CURRENT_BINARY_DIR
foreach( _F ${DH_INPUT} )
	# strip the .in part
	string( REGEX REPLACE ".in$" "" _F_WE ${_F} )
	configure_file( ${_F} ${_F_WE} @ONLY )
endforeach() 

# compat and control is only needed for running the debhelpers,
# CMake is going to make up the one that ends up in the deb.
file( WRITE ${CMAKE_CURRENT_BINARY_DIR}/compat "9" )
if( NOT CPACK_DEBIAN_PACKAGE_NAME )
	string( TOLOWER "${CPACK_PACKAGE_NAME}" CPACK_DEBIAN_PACKAGE_NAME )
endif()
file( WRITE ${CMAKE_CURRENT_BINARY_DIR}/control "Package: ${CPACK_DEBIAN_PACKAGE_NAME}\nArchitecture: any\nSource: ${CPACK_DEBIAN_PACKAGE_NAME}\n" )

# Some debhelpers need fakeroot, we use it for all of them
find_program( FAKEROOT fakeroot )
if( NOT FAKEROOT )
	message( SEND_ERROR "fakeroot not found, please install" )
endif()

find_program( DEBHELPER dh_prep )
if( NOT DEBHELPER )
	message( SEND_ERROR "debhelper not found, please install" )
endif()

# Compose a string with a semicolon-seperated list of debhelpers
foreach( _DH ${DH_RUN} )
	set( _DH_RUN_SC_LIST "${_DH_RUN_SC_LIST} ${_DH} ;" )
endforeach()

# Making sure the debhelpers run each time we change one of ${DH_INPUT}
add_custom_command(
	OUTPUT dhtimestamp

	# dh_prep is needed to clean up, dh_* aren't idempotent
	COMMAND ${FAKEROOT} dh_prep
	
	# I haven't found another way to run a list of commands here
	COMMAND ${FAKEROOT} -- sh -c "${_DH_RUN_SC_LIST}"
	
	# needed to create the files we'll use	
	COMMAND ${FAKEROOT} dh_installdeb
	
	COMMAND ${FAKEROOT} dh_installinit

	COMMAND touch ${CMAKE_CURRENT_BINARY_DIR}/dhtimestamp
	COMMAND mkdir ${CMAKE_CURRENT_BINARY_DIR}/cmakedh
	WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/..
	DEPENDS ${DH_INPUT}
	COMMENT "Running debhelpers"
	VERBATIM
)

add_custom_target( dhtarget ALL
	DEPENDS dhtimestamp
)

# these files are generated by debhelpers from our templates
foreach( _F ${DH_GENERATED_CONTROL_EXTRA} )
	set( CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA
			${CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA} 
			${CMAKE_CURRENT_BINARY_DIR}/${CPACK_DEBIAN_PACKAGE_NAME}/DEBIAN/${_F}
			CACHE INTERNAL ""
	)
endforeach()

# This will copy the generated dhhelper-files to our to-be-cpacked-directory.
# CPACK_INSTALL_SCRIPT must be set to the value of CPACK_DEBIAN_INSTALL_SCRIPT in the file
# pointed to by CPACK_PROJECT_CONFIG_FILE.
set( CPACK_DEBIAN_INSTALL_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/CMakeDebHelperInstall.cmake CACHE INTERNAL "" )
