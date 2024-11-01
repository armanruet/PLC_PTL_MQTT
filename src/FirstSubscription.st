FUNCTION_BLOCK FirstSubscription
VAR_INPUT
END_VAR
VAR_OUTPUT
    fPayload: INT;
END_VAR
VAR
    collector: MQTT.CallbackCollector;
    SUB1: MQTT.MQTTSubscribe;
    init: BOOL;
    receiver: MQTT.ReceiveString;
END_VAR
IF NOT init THEN
    init := TRUE;
    SUB1.SetMqttInOut(MQTT_IN_OUT := PLC_PRG.MQTT_IN_OUT);
    collector.put(instance := receiver);
    receiver.initAsFindTopic(compString := ADR('Test/PTL_1'), returnHit := TRUE);
END_IF
fPayload := STRING_TO_INT(receiver.MQTTReceived);
SUB1(
    Subscribe := TRUE,
    Topic := ADR('Test/PTL_1'),
    QoSSubscribe := MQTT.QoS.ExactlyOnce,
    ExpectingString := TRUE,
    Callback := collector
);