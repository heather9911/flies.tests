cmake_minimum_required(VERSION 2.4)
####################################################################
# Init Definition
####################################################################
PROJECT(flies-test NONE)
SET(CMAKE_ALLOW_LOOSE_LOOP_CONSTRUCTS ON)
MESSAGE("CMake version=${CMAKE_VERSION}")

SET(ENV{LC_ALL} "C")

SET(TEST_CFG "test.cfg")
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR})
INCLUDE(ManageVariable)

####################################################################
# Project specific definition
####################################################################
SET(PROJECT_DESCRIPTION "Test system for flies.openl10n.net")


### Override with environment variables
SET(OVERRIDABLE_VARS "BASE_URL" "FLIES_URL" "BROWSERS_TO_TEST" "SELENIUM_SERVER_PORT")
FOREACH(_envVar  ${OVERRIDABLE_VARS})
    IF(NOT "$ENV{${_envVar}}" STREQUAL "")
	SET(${_envVar} "$ENV{${_envVar}}")
    ENDIF()
ENDFOREACH()

SETTING_FILE_GET_ALL_VARIABLES("${TEST_CFG}" NOREPLACE UNQUOTED NOESCAPE_SEMICOLON)

### Print with environment variables
FOREACH(_envVar  ${OVERRIDABLE_VARS})
    SET(_envVal "${${_envVar}}")
    MESSAGE("${_envVar}=${_envVal}")
ENDFOREACH()

SET(FUNCTIONS_DIR selenium/src/functions)
SET(FUNCTIONS_DIR_ABSOLUTE ${CMAKE_SOURCE_DIR}/selenium/src/functions)
SET(TEST_ROOT_ABSOLUTE "${CMAKE_SOURCE_DIR}/${TEST_ROOT}")
SET(PRIVILEGE_TEST_ROOT_ABSOLUTE "${CMAKE_SOURCE_DIR}/${PRIVILEGE_TEST_ROOT}")
SET(RESULT_DIR_ABSOLUTE "${CMAKE_SOURCE_DIR}/${RESULT_DIR}")
SET(TEST_ROLES ADMIN NORMAL)

#===================================================================
# Search Paths
SET(MAVEN_REPOSITORY "$ENV{HOME}/.m2/repository/")
SET(MAVEN_SELENIUM_SERVER_PATH "${MAVEN_REPOSITORY}/org/seleniumhq/selenium/server/selenium-server/")
SET(SELENIUM_SEARCH_PATHS $ENV{HOME} ${MAVEN_SELENIUM_SERVER_PATH} /usr/share/java ${PWD})


#===================================================================
# Macro FIND_FILE_IN_DIRS
MACRO(FIND_FILE_IN_DIRS var pattern searchPaths)
    #MESSAGE("pattern=${pattern} searchPaths=${searchPaths}")
    EXECUTE_PROCESS(COMMAND ${CMAKE_SOURCE_DIR}/scripts/find_file_in_paths.sh ${pattern} "${searchPaths}"
	OUTPUT_VARIABLE _result)
    #MESSAGE("_result=${_result}")
    IF ( _result STREQUAL "NOT_FOUND")
	SET(${var} "NOTFOUND")
    ELSE()
	STRING_TRIM( _result "${_result}")
	SET( ${var} "${_result}")
    ENDIF()
ENDMACRO()

MACRO(FIND_FILES_IN_DIR var pattern searchPath)
    EXECUTE_PROCESS(COMMAND find ${searchPath} -name "${pattern}" -printf "%p;"
	OUTPUT_VARIABLE _result)
    IF ( _result STREQUAL "")
	SET(${var} "NOTFOUND")
    ELSE()
	SET(${var} ${_result})
    ENDIF()
ENDMACRO()

####################################################################
# Dependencies
####################################################################
FIND_PROGRAM(SELENIUM_SERVER_CMD selenium-server)
IF(${SELENIUM_SERVER_CMD} STREQUAL "SELENIUM_SERVER_CMD-NOTFOUND")
    # find selenium server jar
    FIND_FILE_IN_DIRS(SELENIUM_SERVER_JAR "selenium-server*.jar" "${SELENIUM_SEARCH_PATHS}")
    IF ("${SELENIUM_SERVER_JAR}" STREQUAL "NOTFOUND")
        MESSAGE(FATAL_ERROR "selenium-server not found, install it please.")
    ENDIF()
    SET(SELENIUM_SERVER_CMD java -jar ${SELENIUM_SERVER_JAR})
ENDIF()
#MESSAGE("SELENIUM_SERVER_CMD=${SELENIUM_SERVER_CMD}")

### Find the browser binary
FOREACH(_browser ${BROWSERS_TO_TEST})
    FIND_FILE_IN_DIRS(${_browser}_BIN "${${_browser}_BIN_NAME}" "${${_browser}_SEARCH_PATHS}")
    IF("${${_browser}_BIN}" STREQUAL "NOTFOUND")
	MESSAGE(FATAL_ERROR "Cannot find ${_browser} with ${${_browser}_BIN_NAME}, install it please.")
    ELSE()
	MESSAGE("${_browser}_BIN=${${_browser}_BIN}")
    ENDIF()
ENDFOREACH()

####################################################################
# Stamps
#
SET(PUBLICAN_STAMP publican.stamp)
SET(UPDATE_PO_PUBLICAN_STAMP ".update.po.${PUBLICAN_STAMP}")
SET(UPDATE_POT_PUBLICAN_STAMP ".update.pot.${PUBLICAN_STAMP}")

SET(PY_STAMP "py.stamp")
SET(PROJ_PY_STAMP ".proj.${PY_STAMP}")
SET(VER_PY_STAMP ".ver.${PY_STAMP}")
SET(UPLOADED_POT_PY_STAMP ".upload.pot.${PY_STAMP}")
SET(UPLOADED_PO_PY_STAMP ".upload.po.${PY_STAMP}")

SET(MVN_STAMP "mvn.stamp")
SET(PROJ_MVN_STAMP ".proj.${MVN_STAMP}")
SET(VER_MVN_STAMP ".ver.${MVN_STAMP}")
SET(UPLOADED_POT_MVN_STAMP ".upload.pot.${MVN_STAMP}")
SET(UPLOADED_PO_MVN_STAMP ".upload.po.${MVN_STAMP}")

#===================================================================
# Python targets
#

MACRO(ADD_PY_CLIENT_TARGETS proj)
    SET(_projVers "${${proj}_VERS}")
    FOREACH(_ver ${_projVers})
	FOREACH(_lang ${langs})
	    ADD_CUSTOM_COMMAND(OUTPUT
		${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_PO_PY_STAMP}
		COMMAND flies publican update --project-id ${proj}--version-id
		${_ver}
		COMMAND touch
		${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_PO_PY_STAMP}
		DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_POT_PY_STAMP}
		COMMENT "  [Python] Uploading po for proj ${proj} ver ${_ver}"
		)
	ENDFOREACH(_lang ${langs})
    ENDFOREACH(_ver ${_projVers})
ENDMACRO(ADD_PY_CLIENT_TARGETS  proj)

#===================================================================
# Maven targets
#
MACRO(ADD_MVN_CLIENT_TARGETS proj )
    SET(_projVers "${${proj}_VERS}")
    MESSAGE("MVN_CLIENT: ${proj} _projVers=${_projVers}")
    ADD_CUSTOM_TARGET(flies_publican_push_mvn ALL)

    FOREACH(_ver ${_projVers})
	ADD_CUSTOM_TARGET(flies_publican_push_mvn_${proj}_${_ver} ALL
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_POT_MVN_STAMP}
	    )

	ADD_DEPENDENCIES(flies_publican_push_mvn
	    flies_publican_push_mvn_${proj}_${_ver})

	ADD_CUSTOM_COMMAND(OUTPUT
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_POT_MVN_STAMP}
	    COMMAND  mvn flies:publican-push -Dflies.username=admin
	    -Dflies.key=${KEY} -Dflies.project=${proj}
	    -Dflies.projectVersion=${_ver} -Dflies.srcDir=${SAMPLE_PROJ_DIR}/${proj}/${_ver} -Dflies.url=${FLIES_URL}
	    COMMAND touch ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_PO_PY_STAMP}
	    COMMAND touch ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPLOADED_POT_PY_STAMP}
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/.${_ver}${VER_MVN_STAMP}
	    COMMENT "  [Mvn] Uploading pot and po for proj ${proj} ver ${_ver}"
	    )

	ADD_CUSTOM_COMMAND(OUTPUT
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/.${_ver}${VER_MVN_STAMP}
	    COMMAND mvn flies:putversion -Dflies.username=admin
	    -Dflies.key=${KEY} -Dflies.version.slug=${_ver}
	    -Dflies.version.project=${proj} -Dflies.version.name="Ver ${_ver}"
	    -Dflies.version.desc="Desc of ${_ver}" -Dflies.url=${FLIES_URL}
	    COMMAND touch ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/.${_ver}${VER_MVN_STAMP}
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${PROJ_MVN_STAMP}
	    COMMENT "  [Mvn] Creating version: proj ${proj} ver ${_ver}"
	    )

    ENDFOREACH(_ver ${_projVers})

    ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}/${proj}/${PROJ_MVN_STAMP}
	COMMAND mvn flies:putproject -Dflies.username=admin -Dflies.key=${KEY}
	-Dflies.project.slug=${proj} -Dflies.project.name=${${proj}_NAME}
	-Dflies.project.desc=${${proj}_DESC} -Dflies.url=${FLIES_URL}
	COMMAND touch ${SAMPLE_PROJ_DIR}/${proj}/${PROJ_MVN_STAMP}
	DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/flies.xml
	COMMENT "  [Mvn] Creating proj: proj ${proj}:${${proj}_NAME}"
	)

ENDMACRO(ADD_MVN_CLIENT_TARGETS proj)

#===================================================================
# Common targets
#
MACRO(ADD_PUBLICAN_PROJECT proj client)
    SET(_projVers "${${proj}_VERS}")
    ADD_CUSTOM_TARGET(generate_flies_xml ALL)

    FOREACH(_ver ${_projVers})
	ADD_CUSTOM_TARGET(generate_flies_xml_${proj}_${_ver}  ALL
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/flies.xml
	    )

	ADD_DEPENDENCIES(generate_flies_xml generate_flies_xml_${proj}_${_ver})

	ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/flies.xml
	    COMMAND scripts/generate_flies_xml.sh ${SAMPLE_PROJ_DIR} ${proj}
	    ${_ver} ${LANGS}
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/pot
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_PO_PUBLICAN_STAMP}
	    COMMENT "   Generate ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/flies.xml"
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_PO_PUBLICAN_STAMP}
	    COMMAND publican update_po --config publican.cfg.striped --langs "${LANGS}"
	    WORKING_DIRECTORY ${SAMPLE_PROJ_DIR}/${proj}/${_ver}
	    DEPENDS  ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_POT_PUBLICAN_STAMP}
	    COMMENT "   Generate ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_PO_PUBLICAN_STAMP}"
	    )

	ADD_CUSTOM_COMMAND(OUTPUT  ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_POT_PUBLICAN_STAMP}
	    COMMAND publican update_pot --config publican.cfg.striped
	    WORKING_DIRECTORY ${SAMPLE_PROJ_DIR}/${proj}/${_ver}
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/publican.cfg.striped
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/pot
	    COMMENT "   Generate
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/${UPDATE_POT_PUBLICAN_STAMP}"
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/publican.cfg.striped
	    COMMAND sed -e "s/brand:.*//" publican.cfg >  publican.cfg.striped
	    WORKING_DIRECTORY ${SAMPLE_PROJ_DIR}/${proj}/${_ver}
	    DEPENDS ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/publican.cfg
	    COMMENT "   Generate  ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/publican.cfg.striped"
	    VERBATIM
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/publican.cfg
	    ${SAMPLE_PROJ_DIR}/${proj}/${_ver}/pot
	    COMMAND perl scripts/get_project.pl ${SAMPLE_PROJ_DIR} ${proj}
	    ${${proj}_REPO_TYPE} ${_ver} ${${proj}_URL_${_ver}}
	    COMMENT "   Get sources of ${proj} ${_ver}:${${proj}_NAME}"
	    DEPENDS ${SAMPLE_PROJ_DIR}
	    )
    ENDFOREACH(_ver ${_projVers})

    MESSAGE("client=${client}")
    IF("${client}" STREQUAL "mvn")
	MESSAGE("2client=${client}")
	ADD_MVN_CLIENT_TARGETS(proj)
    ENDIF("${client}" STREQUAL "mvn")
ENDMACRO(ADD_PUBLICAN_PROJECT proj client)

ADD_CUSTOM_COMMAND(OUTPUT ${SAMPLE_PROJ_DIR}
    COMMAND mkdir -p ${SAMPLE_PROJ_DIR}
    )

####################################################################
# Retrieve projects
#
FOREACH(_mvnProj ${MVN_PROJECTS})
    ADD_PUBLICAN_PROJECT(${_mvnProj} mvn)
ENDFOREACH(_mvnProj ${MVN_PROJECTS})



####################################################################
# Test Suites.
####################################################################
ENABLE_TESTING()

#===================================================================
# Generate test suites.
ADD_SUBDIRECTORY(selenium/src)
