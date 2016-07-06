let _ = Callback.register "MITLS_FFI_Config" TestClient13.ffiConfig;
        Callback.register "MITLS_FFI_PrepareClientHello" TestClient13.ffiPrepareClientHello;
        Callback.register "MITLS_FFI_HandleServerHello" TestClient13.ffiHandleServerHello;
        Callback.register "MITLS_FFI_HandleCertificateVerify12" TestClient13.ffiHandleCertificateVerify12;
        Callback.register "MITLS_FFI_HandleServerKeyExchange" TestClient13.ffiHandleServerKeyExchange;
        Callback.register "MITLS_FFI_HandleServerHelloDone" TestClient13.ffiHandleServerHelloDone;
        Callback.register "MITLS_FFI_PrepareClientKeyExchange" TestClient13.ffiPrepareClientKeyExchange;
        Callback.register "MITLS_FFI_PrepareChangeCipherSpec" TestClient13.ffiPrepareChangeCipherSpec;
        Callback.register "MITLS_FFI_PrepareHandshake" TestClient13.ffiPrepareHandshake;
        Callback.register "MITLS_FFI_HandleChangeCipherSpec" TestClient13.ffiHandleChangeCipherSpec;
        Callback.register "MITLS_FFI_HandleServerFinished" TestClient13.ffiHandleServerFinished;
        Callback.register "MITLS_FFI_PrepareSend" TestClient13.ffiPrepareSend;
        Callback.register "MITLS_FFI_HandleReceive" TestClient13.ffiHandleReceive;
        Callback.register "MITLS_FFI_Connect13" TestClient13.ffiConnect13;
        Callback.register "MITLS_FFI_PrepareSend13" TestClient13.ffiPrepareSend13;
        Callback.register "MITLS_FFI_HandleReceive13" TestClient13.ffiHandleReceive13;
