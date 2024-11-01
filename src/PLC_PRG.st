PROGRAM PLC_PRG
VAR
    awCOM0st: ARRAY [1..50] OF WORD;
    awCOM1st: ARRAY [1..50] OF WORD;
    awCOM0i: ARRAY [1..50] OF WORD;
    awCOM1i: ARRAY [1..50] OF WORD;
    awCOM0d: ARRAY [1..50] OF WORD;
    awCOM1d: ARRAY [1..50] OF WORD;
    awARGEEin: ARRAY [0..239] OF WORD;
    awARGEEout: ARRAY [0..239] OF WORD;
    i: UINT;
    restart: BOOL;
    active_com0: UINT;
    active_com1: UINT;
    xManual: BOOL;
    In, In2, In3, In4: BOOL; // Boolean touch inputs
    ColorPTL1, ColorPTL2, ColorPTL3, ColorPTL4: WORD; // Color values as WORDs
    ValuePTL1, ValuePTL2, ValuePTL3, ValuePTL4: WORD; // Output values for each PTL sensor
    sPayload: INT ; // Your message in JSON format
    MQTT_IN_OUT: MQTT.MQTT_IN_OUT;
    FirstPublish: FirstPublish;
    FirstSubscription: FirstSubscription;
    timerCounter: UINT := 0;
    timerDone: BOOL;
    activePTL: INT := 0;
    timerRunning: BOOL := FALSE;

    lastTouchedPTL: INT := 0;
    publishTrigger: BOOL := FALSE;
    // Debug variables
    debugLastPublishTrigger: BOOL;
    debugLastPublishPayload: STRING(20);
    debugPublishSuccess: BOOL;
    debugPublishAttempts: UINT := 0;
    debugLastReceivedMQTT: INT;
    debugSubscriptionActive: BOOL;
    debugMQTTReceived: BOOL := FALSE;
    debugTouchDetected: BOOL := FALSE;
    debugPublishAttempted: BOOL := FALSE;

    lastPublishedPTL: INT := 0;
    touchOccurred: BOOL := FALSE;

END_VAR
// Read inputs from the hardware
active_com0 := awARGEEin[0];
active_com1 := awARGEEin[100];
FOR i := 1 TO 50 DO
    awCOM0st[i] := awARGEEin[i];
    awCOM1st[i] := awARGEEin[100 + i];
    IF NOT xManual THEN
        awCOM0i[i] := awCOM0st[i];
        IF awCOM0st[i] > 0 THEN
            awCOM0d[i] := i;
        ELSE
            awCOM0d[i] := 0;
        END_IF
        awCOM1i[i] := awCOM1st[i];
        IF awCOM1st[i] > 0 THEN
            awCOM1d[i] := i;
        ELSE
            awCOM1d[i] := 0;
        END_IF
    END_IF
    awARGEEout[i] := awCOM0i[i];
    awARGEEout[i + 100] := awCOM1i[i];
    awARGEEout[i + 50] := awCOM0d[i];
    awARGEEout[i + 150] := awCOM1d[i];
END_FOR
// MQTT client handling
MQTT_IN_OUT.clientFB(
    MQTT_IN_OUT := MQTT_IN_OUT,
    ENABLE := TRUE,
    URL := 'broker.emqx.io:1883',
    TLS := FALSE
);
// Handle MQTT subscription
FirstSubscription();
debugSubscriptionActive := FirstSubscription.SUB1.Subscribe;
IF FirstSubscription.fPayload > 0 THEN
    activePTL := FirstSubscription.fPayload;
    debugLastReceivedMQTT := activePTL;
    debugMQTTReceived := TRUE;

    // Reset all PTLs
    ColorPTL1 := 0;
    ColorPTL2 := 0;
    ColorPTL3 := 0;
    ColorPTL4 := 0;

    // Set the active PTL to green
    CASE activePTL OF
        1: ColorPTL1 := 2;
        2: ColorPTL2 := 2;
        3: ColorPTL3 := 2;
        4: ColorPTL4 := 2;
    ELSE
        // If activePTL > 4, all PTLs remain off
    END_CASE;

    // Update outputs
    %QW0 := ColorPTL1;
    %QW2 := ColorPTL2;
    %QW4 := ColorPTL3;
    %QW6 := ColorPTL4;

    // Set values
    ValuePTL1 := 1;
    ValuePTL2 := 2;
    ValuePTL3 := 3;
    ValuePTL4 := 4;

    %QW1 := ValuePTL1;
    %QW3 := ValuePTL2;
    %QW5 := ValuePTL3;
    %QW7 := ValuePTL4;

    // Don't trigger publish for new activePTL
    publishTrigger := FALSE;
ELSE
    debugMQTTReceived := FALSE;
END_IF
// Read the touch inputs as booleans
In := %IW0 <> 0;
In2 := %IW1 <> 0;
In3 := %IW2 <> 0;
In4 := %IW3 <> 0;
// Handle PTL interactions
IF In OR In2 OR In3 OR In4 THEN
    debugTouchDetected := TRUE;
    touchOccurred := TRUE;
    IF In THEN
        lastTouchedPTL := 1;
    ELSIF In2 THEN
        lastTouchedPTL := 2;
    ELSIF In3 THEN
        lastTouchedPTL := 3;
    ELSIF In4 THEN
        lastTouchedPTL := 4;
    END_IF;

    IF lastTouchedPTL <> activePTL THEN
        // Wrong PTL touched, turn it red for 1 second
        CASE lastTouchedPTL OF
            1: ColorPTL1 := 1;
            2: ColorPTL2 := 1;
            3: ColorPTL3 := 1;
            4: ColorPTL4 := 1;
        END_CASE;

        // Start timer
        timerRunning := TRUE;
        timerCounter := 0;
    END_IF;
ELSE
    debugTouchDetected := FALSE;
    touchOccurred := FALSE;
END_IF
// Simple timer implementation
IF timerRunning THEN
    timerCounter := timerCounter + 1;
    IF timerCounter >= 100 THEN // Assuming 10ms scan time, 100 * 10ms = 1 second
        timerRunning := FALSE;
        timerDone := TRUE;
    END_IF;
END_IF;
// Reset wrong PTL after 1 second
IF timerDone THEN
    IF ColorPTL1 = 1 AND activePTL <> 1 THEN ColorPTL1 := 0; END_IF;
    IF ColorPTL2 = 1 AND activePTL <> 2 THEN ColorPTL2 := 0; END_IF;
    IF ColorPTL3 = 1 AND activePTL <> 3 THEN ColorPTL3 := 0; END_IF;
    IF ColorPTL4 = 1 AND activePTL <> 4 THEN ColorPTL4 := 0; END_IF;
    timerDone := FALSE;
END_IF;
// Update outputs
%QW0 := ColorPTL1;
%QW2 := ColorPTL2;
%QW4 := ColorPTL3;
%QW6 := ColorPTL4;
// Publish MQTT message only when a PTL is touched and it's different from the last published PTL
IF touchOccurred AND lastTouchedPTL <> lastPublishedPTL THEN
    sPayload := lastTouchedPTL;
    FirstPublish(
        triggerPublish := TRUE,
        payloadToSend := sPayload
    );
    debugPublishAttempts := debugPublishAttempts + 1;
    debugPublishAttempted := TRUE;
    lastPublishedPTL := lastTouchedPTL;
ELSE
    FirstPublish(
        triggerPublish := FALSE,
        payloadToSend := 0
    );
    debugPublishAttempted := FALSE;
END_IF
// Capture debug information
debugLastPublishTrigger := FirstPublish.debugTrigger;
debugLastPublishPayload := FirstPublish.debugPayload;
debugPublishSuccess := FirstPublish.publishSuccess;
// Reset debug counter if publish was successful
IF debugPublishSuccess THEN
    debugPublishAttempts := 0;
END_IF
// Handle restart condition
IF restart THEN
    activePTL := 0;
    ColorPTL1 := 0;
    ColorPTL2 := 0;
    ColorPTL3 := 0;
    ColorPTL4 := 0;
    awARGEEout[0] := 1; // Indicate a restart or reset
ELSE
    awARGEEout[0] := 0;
END_IF