*** Settings ***
Documentation    Test certificate in OpenBMC.

Resource         ../../lib/resource.robot
Resource         ../../lib/bmc_redfish_resource.robot
Resource         ../../lib/openbmc_ffdc.robot
Resource         ../../lib/certificate_utils.robot
Library          String

Force Tags       Certificate_Test

Suite Setup      Suite Setup Execution
Test Teardown    Test Teardown Execution


** Test Cases **

Verify Server Certificate Replace
    [Documentation]  Verify server certificate replace.
    [Tags]  Verify_Server_Certificate_Replace
    [Template]  Replace Certificate Via Redfish

    # cert_type  cert_format                         expected_status
    Server       Valid Certificate Valid Privatekey  ok
    Server       Empty Certificate Valid Privatekey  error
    Server       Valid Certificate Empty Privatekey  error
    Server       Empty Certificate Empty Privatekey  error


Verify Client Certificate Replace
    [Documentation]  Verify client certificate replace.
    [Tags]  Verify_Client_Certificate_Replace
    [Template]  Replace Certificate Via Redfish

    # cert_type  cert_format                         expected_status
    Client       Valid Certificate Valid Privatekey  ok
    Client       Empty Certificate Valid Privatekey  error
    Client       Valid Certificate Empty Privatekey  error
    Client       Empty Certificate Empty Privatekey  error


Verify CA Certificate Replace
    [Documentation]  Verify CA certificate replace.
    [Tags]  Verify_CA_Certificate_Replace
    [Template]  Replace Certificate Via Redfish

    # cert_type  cert_format        expected_status
    CA           Valid Certificate  ok
    CA           Empty Certificate  error


Verify Client Certificate Install
    [Documentation]  Verify client certificate install.
    [Tags]  Verify_Client_Certificate_Install
    [Template]  Install And Verify Certificate Via Redfish

    # cert_type  cert_format                         expected_status
    Client       Valid Certificate Valid Privatekey  ok
    Client       Empty Certificate Valid Privatekey  error
    Client       Valid Certificate Empty Privatekey  error
    Client       Empty Certificate Empty Privatekey  error


Verify CA Certificate Install
    [Documentation]  Verify CA certificate install.
    [Tags]  Verify_CA_Certificate_Install
    [Template]  Install And Verify Certificate Via Redfish

    # cert_type  cert_format        expected_status
    CA           Valid Certificate  ok
    CA           Empty Certificate  error


Verify Server Certificate View Via Openssl
    [Documentation]  Verify server certificate via openssl command.
    [Tags]  Verify_Server_Certificate_View_Via_Openssl

    redfish.Login

    ${cert_file_path}=  Generate Certificate File Via Openssl  Valid Certificate Valid Privatekey
    ${bytes}=  OperatingSystem.Get Binary File  ${cert_file_path}
    ${file_data}=  Decode Bytes To String  ${bytes}  UTF-8

    ${certificate_dict}=  Create Dictionary
    ...  @odata.id=/redfish/v1/Managers/bmc/NetworkProtocol/HTTPS/Certificates/1
    ${payload}=  Create Dictionary  CertificateString=${file_data}
    ...  CertificateType=PEM  CertificateUri=${certificate_dict}

    ${resp}=  redfish.Post  /redfish/v1/CertificateService/Actions/CertificateService.ReplaceCertificate
    ...  body=${payload}

    Wait Until Keyword Succeeds  2 mins  15 secs  Verify Certificate Visible Via OpenSSL  ${cert_file_path}


*** Keywords ***

Install And Verify Certificate Via Redfish
    [Documentation]  Install and verify certificate using Redfish.
    [Arguments]  ${cert_type}  ${cert_format}  ${expected_status}

    # Description of argument(s):
    # cert_type           Certificate type (e.g. "Client" or "CA").
    # cert_format         Certificate file format
    #                     (e.g. "Valid_Certificate_Valid_Privatekey").
    # expected_status     Expected status of certificate replace Redfish
    #                     request (i.e. "ok" or "error").

    redfish.Login
    Delete Certificate Via BMC CLI  ${cert_type}

    ${time}=  Set Variable If  '${cert_format}' == 'Expired Certificate'  -10  365
    ${cert_file_path}=  Generate Certificate File Via Openssl  ${cert_format}  ${time}
    ${bytes}=  OperatingSystem.Get Binary File  ${cert_file_path}
    ${file_data}=  Decode Bytes To String  ${bytes}  UTF-8

    ${certificate_uri}=  Set Variable If
    ...  '${cert_type}' == 'Client'  ${REDFISH_LDAP_CERTIFICATE_URI}
    ...  '${cert_type}' == 'CA'  ${REDFISH_CA_CERTIFICATE_URI}

    Install Certificate File On BMC  ${certificate_uri}  ${expected_status}  data=${file_data}

    # Adding delay after certificate installation.
    Sleep  30s

    ${cert_file_content}=  OperatingSystem.Get File  ${cert_file_path}
    ${bmc_cert_content}=  Run Keyword If  '${expected_status}' == 'ok'  redfish_utils.Get Attribute
    ...  ${certificate_uri}/1  CertificateString

    Run Keyword If  '${expected_status}' == 'ok'  Should Contain  ${cert_file_content}  ${bmc_cert_content}


Install Certificate File On BMC
    [Documentation]  Install certificate file in BMC using POST operation.
    [Arguments]  ${uri}  ${status}=ok  &{kwargs}

    # Description of argument(s):
    # uri         URI for installing certificate file via REST
    #             e.g. "/xyz/openbmc_project/certs/server/https".
    # status      Expected status of certificate installation via REST
    #             e.g. error, ok.
    # kwargs      A dictionary of keys/values to be passed directly to
    #             POST Request.

    Initialize OpenBMC  quiet=${quiet}

    ${headers}=  Create Dictionary  Content-Type=application/octet-stream
    ...  X-Auth-Token=${XAUTH_TOKEN}
    Set To Dictionary  ${kwargs}  headers  ${headers}

    ${ret}=  Post Request  openbmc  ${uri}  &{kwargs}

    Run Keyword If  '${status}' == 'ok'
    ...  Should Be Equal As Strings  ${ret.status_code}  ${HTTP_OK}
    ...  ELSE IF  '${status}' == 'error'
    ...  Should Be Equal As Strings  ${ret.status_code}  ${HTTP_INTERNAL_SERVER_ERROR}

    Delete All Sessions


Replace Certificate Via Redfish
    [Documentation]  Test 'replace certificate' operation in the BMC via Redfish.
    [Arguments]  ${cert_type}  ${cert_format}  ${expected_status}

    # Description of argument(s):
    # cert_type           Certificate type (e.g. "Server" or "Client").
    # cert_format         Certificate file format
    #                     (e.g. Valid_Certificate_Valid_Privatekey).
    # expected_status     Expected status of certificate replace Redfish
    #                     request (i.e. "ok" or "error").

    # Install certificate before replacing client or CA certificate.
    Run Keyword If  '${cert_type}' == 'Client'
    ...    Install And Verify Certificate Via Redfish  ${cert_type}  Valid Certificate Valid Privatekey  ok
    ...  ELSE IF  '${cert_type}' == 'CA'
    ...    Install And Verify Certificate Via Redfish  ${cert_type}  Valid Certificate  ok

    redfish.Login

    ${time}=  Set Variable If  '${cert_format}' == 'Expired Certificate'  -10  365
    ${cert_file_path}=  Generate Certificate File Via Openssl  ${cert_format}  ${time}

    ${bytes}=  OperatingSystem.Get Binary File  ${cert_file_path}
    ${file_data}=  Decode Bytes To String  ${bytes}  UTF-8

    ${certificate_uri}=  Set Variable If
    ...  '${cert_type}' == 'Server'  ${REDFISH_HTTPS_CERTIFICATE_URI}/1
    ...  '${cert_type}' == 'Client'  ${REDFISH_LDAP_CERTIFICATE_URI}/1
    ...  '${cert_type}' == 'CA'  ${REDFISH_CA_CERTIFICATE_URI}/1

    ${certificate_dict}=  Create Dictionary  @odata.id=${certificate_uri}
    ${payload}=  Create Dictionary  CertificateString=${file_data}
    ...  CertificateType=PEM  CertificateUri=${certificate_dict}

    ${expected_resp}=  Set Variable If  '${expected_status}' == 'ok'  ${HTTP_OK}
    ...  '${expected_status}' == 'error'  ${HTTP_INTERNAL_SERVER_ERROR}
    ${resp}=  redfish.Post  /redfish/v1/CertificateService/Actions/CertificateService.ReplaceCertificate
    ...  body=${payload}  valid_status_codes=[${expected_resp}]

    ${cert_file_content}=  OperatingSystem.Get File  ${cert_file_path}
    ${bmc_cert_content}=  redfish_utils.Get Attribute  ${certificate_uri}  CertificateString

    Run Keyword If  '${expected_status}' == 'ok'
    ...    Should Contain  ${cert_file_content}  ${bmc_cert_content}
    ...  ELSE
    ...    Should Not Contain  ${cert_file_content}  ${bmc_cert_content}


Verify Certificate Visible Via OpenSSL
    [Documentation]  Checks if given certificate is visible via openssl's showcert command.
    [Arguments]  ${cert_file_path}

    # Description of argument(s):
    # cert_file_path           Certificate file path.

    ${cert_file_content}=  OperatingSystem.Get File  ${cert_file_path}
    ${openssl_cert_content}=  Get Certificate Content From BMC Via Openssl
    Should Contain  ${cert_file_content}  ${openssl_cert_content}


Delete Certificate Via BMC CLI
    [Documentation]  Delete certificate via BMC CLI.
    [Arguments]  ${cert_type}

    # Description of argument(s):
    # cert_type           Certificate type (e.g. "Client" or "CA").

    ${certificate_file_path}  ${certificate_service}  ${certificate_uri}=
    ...  Run Keyword If  '${cert_type}' == 'Client'
    ...    Set Variable  /etc/nslcd/certs/cert.pem  phosphor-certificate-manager@nslcd.service
    ...    ${REDFISH_LDAP_CERTIFICATE_URI}
    ...  ELSE IF  '${cert_type}' == 'CA'
    ...    Set Variable  /etc/ssl/certs/Root-CA.pem  phosphor-certificate-manager@authority.service
    ...    ${REDFISH_CA_CERTIFICATE_URI}

    ${file_status}  ${stderr}  ${rc}=  BMC Execute Command
    ...  [ -f ${certificate_file_path} ] && echo "Found" || echo "Not Found"

    Return From Keyword If  "${file_status}" != "Found"
    BMC Execute Command  rm ${certificate_file_path}
    BMC Execute Command  systemctl restart ${certificate_service}
    Wait Until Keyword Succeeds  1 min  10 sec
    ...  Redfish.Get  ${certificate_uri}/1  valid_status_codes=[${HTTP_INTERNAL_SERVER_ERROR}]


Suite Setup Execution
    [Documentation]  Do suite setup tasks.

    # Create certificate sub-directory in current working directory.
    Create Directory  certificate_dir


Test Teardown Execution
    [Documentation]  Do the post test teardown.

    FFDC On Test Case Fail
    redfish.Logout
