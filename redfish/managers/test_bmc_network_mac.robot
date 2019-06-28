*** Settings ***
Documentation  Test BMC network interface functionalities.

Resource       ../../lib/bmc_redfish_resource.robot
Resource       ../../lib/bmc_network_utils.robot
Resource       ../../lib/openbmc_ffdc.robot
Library        ../../lib/bmc_network_utils.py

Suite Setup    Suite Setup Execution
Test Teardown  Test Teardown Execution

Force Tags     MAC_Test

*** Variables ***

# AA:AA:AA:AA:AA:AA series is a valid MAC and does not exist in
# our network, so this is chosen to avoid MAC conflict.
${valid_mac}         AA:E2:84:14:28:79
${zero_mac}          00:00:00:00:00:00
${broadcast_mac}     FF:FF:FF:FF:FF:FF
${out_of_range_mac}  AA:FF:FF:FF:FF:100

# There will be 6 bytes in MAC address (e.g. xx.xx.xx.xx.xx.xx).
# Here trying to configure xx.xx.xx.xx.xx
${less_byte_mac}     AA:AA:AA:AA:BB
# Here trying to configure xx.xx.xx.xx.xx.xx.xx
${more_byte_mac}     AA:AA:AA:AA:AA:AA:BB

# MAC address with special characters.
${special_char_mac}  &A:$A:AA:AA:AA:^^

*** Test Cases ***

Configure Valid MAC And Verify
    [Documentation]  Configure valid MAC via Redfish and verify.
    [Tags]  Configure_Valid_MAC_And_Verify

    Configure MAC Settings  ${valid_mac}  valid

    # Verify whether new MAC is configured on BMC.
    Validate MAC On BMC  ${valid_mac}


Configure Zero MAC And Verify
    [Documentation]  Configure zero MAC via Redfish and verify.
    [Tags]  Configure_Zero_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC address  scenario
    ${zero_mac}    error


Configure Broadcast MAC And Verify
    [Documentation]  Configure broadcast MAC via Redfish and verify.
    [Tags]  Configure_Broadcast_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC address    scenario
    ${broadcast_mac}  error

Configure Invalid MAC And Verify
    [Documentation]  Configure invalid MAC address which is a string.
    [Tags]  Configure_Invalid_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC Address        Expected_Result
    ${special_char_mac}  error

Configure Valid MAC And Check Persistency
    [Documentation]  Configure valid MAC and check persistency.
    [Tags]  Configure_Valid_MAC_And_Check_Persistency

    Configure MAC Settings  ${valid_mac}  valid

    # Verify whether new MAC is configured on BMC.
    Validate MAC On BMC  ${valid_mac}

    # Reboot BMC and check whether MAC is persistent.
    OBMC Reboot (off)
    Validate MAC On BMC  ${valid_mac}

Configure Out Of Range MAC And Verify
    [Documentation]  Configure out of range MAC via Redfish and verify.
    [Tags]  Configure_Out_Of_Range_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC address        scenario
    ${out_of_range_mac}  error

Configure Less Byte MAC And Verify
    [Documentation]  Configure less byte MAC via Redfish and verify.
    [Tags]  Configure_Less_Byte_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC address     scenario
    ${less_byte_mac}  error

Configure More Byte MAC And Verify
    [Documentation]  Configure more byte MAC via Redfish and verify.
    [Tags]  Configure_Less_Byte_MAC_And_Verify

    [Template]  Configure MAC Settings
    # MAC address     scenario
    ${more_byte_mac}  error

*** Keywords ***

Test Teardown Execution
    [Documentation]  Do the post test teardown.

    # Revert to initial MAC address.
    Configure MAC Settings  ${initial_mac_address}  valid

    # Verify whether new MAC is configured on BMC.
    Validate MAC On BMC  ${initial_mac_address}

    FFDC On Test Case Fail
    Redfish.Logout


Suite Setup Execution
    [Documentation]  Do suite setup tasks.

    Redfish.Login

    # Get BMC MAC address.
    ${resp}=  redfish.Get  ${REDFISH_NW_ETH0_URI}
    Set Suite Variable  ${initial_mac_address}  ${resp.dict['MACAddress']}

    Validate MAC On BMC  ${initial_mac_address}

    Redfish.Logout


Configure MAC Settings
    [Documentation]  Configure MAC settings via Redfish.
    [Arguments]  ${mac_address}  ${expected_result}

    # Description of argument(s):
    # mac_address      MAC address of BMC.
    # expected_result  Expected status of MAC configuration.

    Redfish.Login
    ${payload}=  Create Dictionary  MACAddress=${mac_address}

    Redfish.Patch  ${REDFISH_NW_ETH0_URI}  body=&{payload}
    ...  valid_status_codes=[200, 400, 500]

    # After any modification on network interface, BMC restarts network
    # module, wait until it is reachable.

    Wait Until Keyword Succeeds  ${NETWORK_TIMEOUT}  ${NETWORK_RETRY_TIME}
    ...  redfish.Get  ${REDFISH_NW_ETH0_URI}

    # Verify whether new MAC address is populated on BMC system.
    # It should not allow to configure invalid settings.

    ${status}=  Run Keyword And Return Status
    ...  Validate MAC On BMC  ${mac_address}

    Run Keyword If  '${expected_result}' == 'error'
    ...      Should Be Equal  ${status}  ${False}
    ...      msg=Allowing the configuration of an invalid MAC.
    ...  ELSE
    ...      Should Be Equal  ${status}  ${True}
    ...      msg=Not allowing the configuration of a valid MAC.

