FUNCTION_BLOCK FirstPublish
VAR_INPUT
    triggerPublish: BOOL;
    payloadToSend: INT;
END_VAR
VAR_OUTPUT
    debugTrigger: BOOL;
    debugPayload: STRING(20);
    publishSuccess: BOOL;
END_VAR
VAR
    publisher: MQTT.MQTTPublish;
    init: BOOL;
    sendPayload: STRING(20);
    publishAttempted: BOOL := FALSE;
END_VAR
IF NOT init THEN
    init := TRUE;
    publisher.SetMqttInOut(MQTT_IN_OUT := PLC_PRG.MQTT_IN_OUT);
END_IF
// Convert INT to STRING
sendPayload := INT_TO_STRING(payloadToSend);
// Debug outputs
debugTrigger := triggerPublish;
debugPayload := sendPayload;
IF triggerPublish AND NOT publishAttempted THEN
    publisher(
        Topic := ADR('Test/PTL_touch'), // Adjust this topic as needed
        PayloadString := ADR(sendPayload),
        PublishAsString := TRUE,
        QoSIn := MQTT.QoS.ExactlyOnce,
        MRetain := FALSE,
        send := TRUE
    );
    publishAttempted := TRUE;
    publishSuccess := TRUE; // Assume success if we attempt to publish
ELSE
    publisher(
        send := FALSE
    );
    publishAttempted := FALSE;
    publishSuccess := FALSE;
END_IF