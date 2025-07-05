#Requires AutoHotkey v2.0
/**************************************************************************
 * Chrome Automation Library (v2)
 * Converted and optimized from original v1 script
 *************************************************************************/

class Chrome {
    static _http := ComObject("WinHttp.WinHttpRequest.5.1")
    static Prototype.NewTab := Chrome.Prototype.NewPage

    ; Finds an existing debugging instance of Chrome/Edge
    static FindInstance(exeName := "Chrome.exe", debugPort := 0) {
        items := Map()
        filter := Map()
        for item in ComObjGet("winmgmts:").ExecQuery(
            "SELECT CommandLine, ProcessID FROM Win32_Process WHERE Name = '" exeName "' AND CommandLine LIKE '% --remote-debugging-port=%'") {
            parent := ProcessGetParent(item.ProcessID)
            if !items.Has(parent)
                items[item.ProcessID] := [parent, item.CommandLine]
        }
        for pid, data in items {
            if !items.Has(data[1]) && (!debugPort || InStr(data[2], " --remote-debugging-port=" debugPort))
                filter[pid] := data[2]
        }
        for pid, cmd in filter {
            if RegExMatch(cmd, 'i) --remote-debugging-port=(\d+)', &m)
                return { Base: Chrome.Prototype, DebugPort: m[1], PID: pid }
        }
    }

    ; Creates or attaches to a Chrome instance with remote debugging enabled
    __New(urls := '', flags := '', chromePath := '', debugPort := 9222, profilePath := '') {
        if !chromePath {
            try FileGetShortcut A_StartMenuCommon '\\Programs\\Chrome.lnk', &chromePath
            catch {
                chromePath := RegRead('HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\Chrome.exe',, 'C:\\Program Files (x86)\\Google\\Chrome\\Application\\Chrome.exe')
            }
        }
        if !FileExist(chromePath) && !FileExist(chromePath := 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe')
            throw Error('Chrome/Edge could not be found')
        if !IsInteger(debugPort) || debugPort <= 0
            throw Error('DebugPort must be a positive integer')
        this.DebugPort := debugPort
        urlString := ''

        SplitPath(chromePath, &exeName)
        urls := urls is Array ? urls : (urls && urls is String ? [urls] : [])
        if inst := Chrome.FindInstance(exeName, debugPort) {
            this.PID := inst.PID
            http := Chrome._http
            for url in urls {
                http.Open('PUT', 'http://127.0.0.1:' this.DebugPort '/json/new?' url)
                http.Send()
            }
            return
        }

        if profilePath && !DirExist(profilePath)
            DirCreate(profilePath)
        for url in urls
            urlString .= ' ' CliEscape(url)

        hasOther := ProcessExist(exeName)
        Run(CliEscape(chromePath) ' --remote-debugging-port=' this.DebugPort ' --remote-allow-origins=*'
            (profilePath ? ' --user-data-dir=' CliEscape(profilePath) : '')
            (flags ? ' ' flags : '') urlString, , , &pid)
        if (hasOther && Sleep(600) || !inst := Chrome.FindInstance(exeName, this.DebugPort))
            throw Error(Format('{1} is not running in debug mode. Try closing all {1} processes and try again', exeName))
        this.PID := pid

        CliEscape(param) => '"' RegExReplace(param, '(\\\\*)"', '$1$1\"') '"'
    }

    ; Terminates Chrome
    Kill() {
        ProcessClose(this.PID)
    }

    ; Returns a list of pages with debug interfaces
    GetPageList() {
        http := Chrome._http
        try {
            http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json')
            http.Send()
            return JSON.parse(http.responseText)
        } catch {
            return []
        }
    }

    ; Finds pages according to matching options
    FindPages(opts, matchMode := 'exact') {
        pages := []
        for pageData in this.GetPageList() {
            fg := true
            for k, v in (opts is Map ? opts : opts.OwnProps()) {
                if !((matchMode = 'exact' && pageData[k] = v)
                    || (matchMode = 'contains' && InStr(pageData[k], v))
                    || (matchMode = 'startswith' && InStr(pageData[k], v) == 1)
                    || (matchMode = 'regex' && pageData[k] ~= v)) {
                        fg := false
                        break
                }
            }
            if fg
                pages.Push(pageData)
        }
        return pages
    }

    ; Opens a new tab
    NewPage(url := 'about:blank', fnCallback?) {
        http := Chrome._http
        http.Open('PUT', 'http://127.0.0.1:' this.DebugPort '/json/new?' url)
        http.Send()
        pageData := JSON.parse(http.responseText)
        if pageData.Has('webSocketDebuggerUrl')
            return Chrome.Page(StrReplace(pageData['webSocketDebuggerUrl'], 'localhost', '127.0.0.1'), fnCallback?)
    }

    ; Closes a tab based on matching options
    ClosePage(opts, matchMode := 'exact') {
        http := Chrome._http
        switch Type(opts) {
            case 'String':
                http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts)
                return http.Send()
            case 'Map':
                if opts.Has('id') {
                    http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts['id'])
                    return http.Send()
                }
            case 'Object':
                if opts.HasProp('id') {
                    http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' opts.id)
                    return http.Send()
                }
        }
        for page in this.FindPages(opts, matchMode)
            http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/close/' page['id']), http.Send()
    }

    ; Activates a page that matches the criteria
    ActivatePage(opts, matchMode := 'exact') {
        http := Chrome._http
        for page in this.FindPages(opts, matchMode) {
            http.Open('GET', 'http://127.0.0.1:' this.DebugPort '/json/activate/' page['id'])
            return http.Send()
        }
    }

    ; Returns a WebSocket connection for a matching page
    GetPageBy(key, value, matchMode := 'exact', index := 1, fnCallback?) {
        matchFn := {
            contains: InStr,
            exact: (a, b) => a = b,
            regex: (a, b) => a ~= b,
            startswith: (a, b) => InStr(a, b) == 1
        }
        count := 0
        fn := matchFn.%matchMode%
        for pageData in this.GetPageList() {
            if fn(pageData[key], value) && ++count == index
                return Chrome.Page(pageData['webSocketDebuggerUrl'], fnCallback?)
        }
    }

    ; Helpers for common queries
    GetPageByURL(value, matchMode := 'startswith', index := 1, fnCallback?) {
        return this.GetPageBy('url', value, matchMode, index, fnCallback?)
    }
    GetPageByTitle(value, matchMode := 'startswith', index := 1, fnCallback?) {
        return this.GetPageBy('title', value, matchMode, index, fnCallback?)
    }
    GetPage(index := 1, type := 'page', fnCallback?) {
        return this.GetPageBy('type', type, 'exact', index, fnCallback?)
    }

    ; Nested class representing a page connection
    class Page extends WebSocket {
        _index := 0
        _responses := Map()
        _callback := 0

        __New(url, events := 0) {
            super.__New(url)
            this._callback := events
            p := ObjPtr(this)
            this.KeepAlive := () => ObjFromPtrAddRef(p)('Browser.getVersion', , false)
            SetTimer(this.KeepAlive, 25000)
        }
        __Delete() {
            if this.KeepAlive {
                SetTimer(this.KeepAlive, 0)
                this.KeepAlive := 0
            }
            super.__Delete()
        }

        Call(domainAndMethod, params?, waitResponse := true) {
            if this.readyState != 1
                throw Error('Not connected to tab')
            id := ++this._index
            this.sendText(JSON.stringify(Map('id', id, 'params', params ?? {}, 'method', domainAndMethod), 0))
            if !waitResponse
                return
            this._responses[id] := false
            while this.readyState = 1 && !this._responses[id]
                Sleep 20
            response := this._responses.Delete(id)
            if !response
                throw Error('Not connected to tab')
            if !(response is Map)
                return response
            if response.Has('error')
                throw Error('Chrome indicated error in response', , JSON.stringify(response['error']))
            try return response['result']
        }

        Evaluate(js) {
            res := this('Runtime.evaluate', {
                expression: js,
                objectGroup: 'console',
                includeCommandLineAPI: JSON.true,
                silent: JSON.false,
                returnByValue: JSON.false,
                userGesture: JSON.true,
                awaitPromise: JSON.false
            })
            if res is Map {
                if res.Has('exceptionDetails')
                    throw Error(res['result']['description'], , JSON.stringify(res['exceptionDetails']))
                return res['result']
            }
        }

        Close() {
            RegExMatch(this.url, 'ws://[\d\.]+:(\d+)/devtools/page/(.+)$', &m)
            http := Chrome._http
            http.Open('GET', 'http://127.0.0.1:' m[1] '/json/close/' m[2])
            http.Send()
            this.__Delete()
        }

        Activate() {
            RegExMatch(this.url, 'ws://[\d\.]+:(\d+)/devtools/page/(.+)$', &m)
            http := Chrome._http
            http.Open('GET', 'http://127.0.0.1:' m[1] '/json/activate/' m[2])
            http.Send()
        }

        WaitForLoad(desiredState := 'complete', interval := 100) {
            while this.Evaluate('document.readyState')['value'] != desiredState
                Sleep interval
        }
        onClose(*) {
            try this.reconnect()
            catch WebSocket.Error
                this.__Delete()
        }
        onMessage(msg) {
            data := JSON.parse(msg)
            if this._responses.Has(id := data.Get('id', 0))
                this._responses[id] := data
            try (this._callback)(data)
        }
    }
}

;#Include 'JSON.ahk'
#Include 'WebSocket.ahk'
