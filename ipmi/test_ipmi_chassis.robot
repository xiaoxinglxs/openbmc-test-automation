*** Settings ***

Documentation    Module to test IPMI chassis functionality.
Resource         ../lib/ipmi_client.robot
Resource         ../lib/openbmc_ffdc.robot

Test Teardown    FFDC On Test Case Fail

*** Test Cases ***

IPMI Chassis Status On
    [Documentation]  This test case verfies system power on status
    ...               using IPMI Get Chassis status command.
    [Tags]  IPMI_Chassis_Status_On

    Redfish Power On  stack_mode=skip  quiet=1
    ${resp}=  Run IPMI Standard Command  chassis status
    ${power_status}=  Get Lines Containing String  ${resp}  System Power
    Should Contain  ${power_status}  on

IPMI Chassis Status Off
    [Documentation]  This test case verfies system power off status
    ...               using IPMI Get Chassis status command.
    [Tags]  IPMI_Chassis_Status_Off

    Redfish Power Off  stack_mode=skip  quiet=1
    ${resp}=  Run IPMI Standard Command  chassis status
    ${power_status}=  Get Lines Containing String  ${resp}  System Power
    Should Contain  ${power_status}  off
