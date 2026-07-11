#!/usr/bin/env swift
// DewQRaft smoke test.
// Loads the real index.html in an offscreen WKWebView, drives the UI with
// synthetic events, and asserts payload construction, QR rendering, and the
// dewQRaftNative bridge protocol (the exact messages the Swift app consumes).
//
// Usage: swift scripts/smoke-test.swift [path/to/index.html]
// Exits 0 when every check passes, 1 otherwise.
// Needs a logged-in GUI session (WebKit spawns helper processes); it opens no windows.

import WebKit

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let defaultHTML = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("index.html")
let htmlURL = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) } ?? defaultHTML

guard FileManager.default.fileExists(atPath: htmlURL.path) else {
    print("FAIL setup — index.html not found at \(htmlURL.path)")
    exit(1)
}

final class SmokeHost: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    private(set) var loaded = false
    private(set) var loadFailed = false
    private(set) var bridgeMessages: [[String: Any]] = []

    init(htmlURL: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 560, height: 520), configuration: configuration)
        super.init()
        webView.configuration.userContentController.add(self, name: "dewQRaftNative")
        webView.navigationDelegate = self
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { loadFailed = true }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { loadFailed = true }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "dewQRaftNative" else { return }
        if let body = message.body as? [String: Any] { bridgeMessages.append(body) }
    }

    func drainBridgeMessages() -> [[String: Any]] {
        defer { bridgeMessages = [] }
        return bridgeMessages
    }
}

func pump(seconds: TimeInterval, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition() && Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
    }
}

var failures = 0
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    if ok {
        print("PASS \(name)")
    } else {
        failures += 1
        print("FAIL \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

let host = SmokeHost(htmlURL: htmlURL)
pump(seconds: 15, until: { host.loaded || host.loadFailed })
guard host.loaded else {
    print("FAIL setup — index.html did not finish loading")
    exit(1)
}

// Evaluates JS that must return a string (use JSON.stringify in the script).
func evalString(_ js: String) -> String {
    var result = ""
    var done = false
    host.webView.evaluateJavaScript(js) { value, error in
        if let error {
            result = "JSERROR: \(error.localizedDescription)"
        } else {
            result = (value as? String) ?? "JSERROR: non-string result"
        }
        done = true
    }
    pump(seconds: 10, until: { done })
    return done ? result : "JSERROR: evaluateJavaScript timed out"
}

// Phase A: pure-JS checks batched into one script that returns a JSON report.
let phaseA = """
(() => {
  const results = [];
  const check = (name, ok, detail) => results.push({ name, ok: !!ok, detail: String(detail ?? "") });
  const $ = (id) => document.getElementById(id);
  const setValue = (el, v) => { el.value = v; el.dispatchEvent(new Event("input", { bubbles: true })); };
  const setSelect = (el, v) => { el.value = v; el.dispatchEvent(new Event("change", { bubbles: true })); };
  const setChecked = (el, v) => { el.checked = v; el.dispatchEvent(new Event("change", { bubbles: true })); };
  const tab = (mode) => document.querySelector(`.tab[data-mode="${mode}"]`).click();
  const payload = () => $("payloadPreview").textContent;
  const status = () => $("statusLabel").textContent;
  const statusIsError = () => $("statusLabel").classList.contains("error");
  const canvasVisible = () => !$("qrCanvas").classList.contains("hidden");
  const buttonsDisabled = () => $("copyPngButton").disabled;
  const darkPixelCount = () => {
    const canvas = $("qrCanvas");
    const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data;
    let dark = 0;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i] < 128 && data[i + 3] > 128) dark++;
    }
    return dark;
  };

  // 1. Defaults
  check("default payload", payload() === "https://dewflash.dev", payload());
  check("default status ready", status() === "Ready" && !statusIsError(), status());
  check("default canvas visible", canvasVisible());
  check("default actions enabled", !buttonsDisabled());
  check("default canvas size 1024", $("qrCanvas").width === 1024, $("qrCanvas").width);
  check("qr has dark modules", darkPixelCount() > 5000, darkPixelCount());

  // 2. Error level changes output
  const pngM = $("qrCanvas").toDataURL("image/png");
  setSelect($("errorLevel"), "H");
  const pngH = $("qrCanvas").toDataURL("image/png");
  check("error level changes qr", pngM !== pngH);
  setSelect($("errorLevel"), "M");

  // 3. Wi-Fi payload with characters that need escaping
  tab("wifi");
  setValue($("wifiSsid"), 'My "Net";x');
  setValue($("wifiPassword"), "p,w:1");
  const wifiExpected = 'WIFI:T:WPA;S:My \\\\"Net\\\\"\\\\;x;P:p\\\\,w\\\\:1;H:false;;';
  check("wifi payload escaping", payload() === wifiExpected, JSON.stringify(payload()));
  setChecked($("wifiHidden"), true);
  check("wifi hidden flag", payload().endsWith("H:true;;"), payload());
  setChecked($("wifiHidden"), false);
  setValue($("wifiSsid"), "");
  check("wifi empty ssid disables actions", buttonsDisabled() && payload() === "Empty", payload());

  // 4. Email payload (BASELINE: URLSearchParams form encoding — '+' for spaces)
  tab("email");
  setValue($("emailTo"), "a@b.c");
  setValue($("emailSubject"), "Team lunch Friday?");
  setValue($("emailBody"), "See you & Bob");
  const mailExpected = "mailto:a@b.c?subject=Team%20lunch%20Friday%3F&body=See%20you%20%26%20Bob";
  check("email payload", payload() === mailExpected, payload());

  // 5. Contact payload (BASELINE: LF line endings, no N: property)
  tab("contact");
  setValue($("contactName"), "Ada Lovelace");
  setValue($("contactPhone"), "+65 9123 4567");
  setValue($("contactEmail"), "ada@lovelace.dev");
  const vcardExpected = [
    "BEGIN:VCARD",
    "VERSION:3.0",
    "N:Ada Lovelace;;;;",
    "FN:Ada Lovelace",
    "TEL:+65 9123 4567",
    "EMAIL:ada@lovelace.dev",
    "END:VCARD"
  ].join("\\r\\n");
  check("contact payload", payload() === vcardExpected, JSON.stringify(payload()));

  // 6. Phone payload (BASELINE: inner whitespace kept)
  tab("phone");
  setValue($("phoneNumber"), " +65 9123 4567 ");
  check("phone payload", payload() === "tel:+6591234567", payload());

  // 7. SMS payload strips whitespace and percent-encodes the body
  tab("sms");
  setValue($("smsNumber"), "+65 9123 4567");
  setValue($("smsBody"), "Hello there");
  check("sms payload", payload() === "sms:+6591234567?body=Hello%20there", payload());

  // 8. UTF-8 content renders
  tab("text");
  setValue($("textValue"), "héllo 🚀");
  check("utf8 renders", status() === "Ready" && canvasVisible(), status());

  // 9. Oversized content fails gracefully
  setValue($("textValue"), "x".repeat(3000));
  check("overflow shows error", statusIsError() && buttonsDisabled(), status());
  check("overflow message friendly", status() === "Too long for one QR code", status());

  // 10. Reset restores defaults
  tab("wifi");
  setSelect($("wifiSecurity"), "WEP");
  $("resetButton").click();
  check("reset restores payload", payload() === "https://dewflash.dev", payload());
  const textTabActive = document.querySelector('.tab[data-mode="text"]').classList.contains("active");
  check("reset returns to text tab", textTabActive);
  check("reset re-enables actions", !buttonsDisabled());
  check("reset restores wifi security", $("wifiSecurity").value === "WPA", $("wifiSecurity").value);

  // 11. Popup theme panel
  $("themeButton").click();
  check("theme panel opens", $("themePanel").classList.contains("active"));
  setValue($("uiAccent"), "#ff0000");
  const accent = document.documentElement.style.getPropertyValue("--accent").trim();
  check("accent applies", accent === "#ff0000", accent);
  $("themeButton").click();
  check("theme panel closes", !$("themePanel").classList.contains("active"));

  return JSON.stringify(results);
})()
"""

let phaseAResult = evalString(phaseA)
if phaseAResult.hasPrefix("JSERROR") {
    print("FAIL phase-a — \(phaseAResult)")
    failures += 1
} else if let data = phaseAResult.data(using: .utf8),
          let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
    for entry in entries {
        check(entry["name"] as? String ?? "unnamed",
              entry["ok"] as? Bool ?? false,
              entry["detail"] as? String ?? "")
    }
} else {
    print("FAIL phase-a — unparseable report: \(phaseAResult)")
    failures += 1
}

// Phase B: native bridge protocol. Each click posts to dewQRaftNative, which
// this harness captures exactly like the real app's WKScriptMessageHandler.
func clickAndCapture(_ buttonId: String) -> [String: Any]? {
    _ = host.drainBridgeMessages()
    let js = "document.getElementById(\"\(buttonId)\").click(); \"clicked\""
    let clicked = evalString(js)
    if clicked.hasPrefix("JSERROR") {
        print("FAIL bridge \(buttonId) — \(clicked)")
        failures += 1
        return nil
    }
    var captured: [[String: Any]] = []
    pump(seconds: 5, until: {
        captured = host.bridgeMessages
        return !captured.isEmpty
    })
    return host.drainBridgeMessages().first
}

_ = evalString("document.getElementById(\"resetButton\").click(); \"reset\"")

if let message = clickAndCapture("copyPngButton") {
    let base64 = message["base64"] as? String ?? ""
    check("bridge copyPng type", message["type"] as? String == "copyPng")
    check("bridge copyPng is png", base64.hasPrefix("iVBOR"), String(base64.prefix(8)))
    check("bridge copyPng has body", base64.count > 2000, "\(base64.count) chars")
    let decodable = Data(base64Encoded: base64) != nil
    check("bridge copyPng decodable", decodable)
} else {
    check("bridge copyPng received", false, "no message captured")
}

if let message = clickAndCapture("copySvgButton") {
    let text = message["text"] as? String ?? ""
    check("bridge copySvg type", message["type"] as? String == "copyText")
    check("bridge copySvg label", message["label"] as? String == "SVG copied")
    check("bridge copySvg is svg", text.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\"") && text.contains("<rect"))
    check("bridge copySvg crisp edges", text.contains("shape-rendering=\"crispEdges\""))
} else {
    check("bridge copySvg received", false, "no message captured")
}

if let message = clickAndCapture("savePngButton") {
    check("bridge savePng type", message["type"] as? String == "save")
    check("bridge savePng name", message["fileName"] as? String == "dewqraft-code.png")
    check("bridge savePng mime", message["mime"] as? String == "image/png")
    check("bridge savePng payload", (message["base64"] as? String)?.hasPrefix("iVBOR") == true)
} else {
    check("bridge savePng received", false, "no message captured")
}

if let message = clickAndCapture("saveSvgButton") {
    check("bridge saveSvg type", message["type"] as? String == "save")
    check("bridge saveSvg name", message["fileName"] as? String == "dewqraft-code.svg")
    check("bridge saveSvg mime", message["mime"] as? String == "image/svg+xml")
    check("bridge saveSvg payload", (message["text"] as? String)?.hasPrefix("<svg") == true)
} else {
    check("bridge saveSvg received", false, "no message captured")
}

// The native-done callback used for toasts must exist and be callable.
let doneHook = evalString("typeof window.dewQRaftNativeDone === \"function\" ? \"ok\" : \"missing\"")
check("native done hook", doneHook == "ok", doneHook)

print(failures == 0 ? "SMOKE OK — all checks passed" : "SMOKE FAILED — \(failures) failing check(s)")
exit(failures == 0 ? 0 : 1)
