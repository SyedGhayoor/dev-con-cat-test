/*
 * Super Pixel — reference embed snippet (candidate-facing example)
 * ---------------------------------------------------------------
 * This is the equivalent of a TrustedForm-style header snippet. A buyer drops
 * ONE tag on their landing page / funnel and the pixel:
 *
 *   1. Boots a "capture session" the moment the page loads and records page
 *      context (URL, referrer, user-agent, a client-side timestamp, and a
 *      site-visit beacon your backend can later match against the submit IP).
 *   2. Watches the lead form as the visitor fills it in (focus / blur / change)
 *      and streams those interactions to your backend in real time.
 *   3. On submit, POSTs the captured lead to YOUR Rails ingestion endpoint,
 *      then subscribes to verification activity for that lead so the page can
 *      render each detection layer's result live.
 *
 * WIRED TO A REAL BACKEND:
 *   - `data-endpoint` points at Api::Pixel::IngestionController (/visit,
 *     /leads). Account/tenant is always resolved server-side from the
 *     pixel_id, never trusted from this payload.
 *   - subscribeToActivity() opens a real EventSource against
 *     Api::Pixel::ActivityController, authorized by the activity_token
 *     returned from POST /leads (not the bare lead_id; see SOLUTION.md for
 *     why a capability token is needed here).
 *   - Pixels themselves are created/scoped through the account-admin UI
 *     (PixelsController), which is what generates the public_id and this
 *     exact snippet text.
 *
 * If `data-endpoint` is omitted, everything below still falls back to a
 * local simulation so this file stays demoable with zero backend running.
 *
 * Embed like this (note the async + data-* attributes):
 *   <script async src="/super-pixel.js"
 *           data-pixel-id="px_9f2a01"
 *           data-endpoint="https://your-rails-app.example/api/pixel"></script>
 */
(function () {
  "use strict";

  var script =
    document.currentScript ||
    (function () {
      var s = document.getElementsByTagName("script");
      return s[s.length - 1];
    })();

  var CONFIG = {
    pixelId: (script && script.getAttribute("data-pixel-id")) || "px_demo",
    // When data-endpoint is absent we run in SIMULATION mode (no network).
    endpoint: (script && script.getAttribute("data-endpoint")) || null,
    // Which layers the pixel advertises it will run. In the real product this
    // comes from the account's enabled_modules; here it's just for the demo.
    layers: [
      "vpn_proxy",
      "anura",
      "trustedform",
      "blacklist_alliance",
      "dnc",
      "phone_validation",
      "email_validation",
      "enrichment",
      "duplicate_detection",
      "voice",
      "consensus",
    ],
  };

  // --- tiny event bus so the host page can render activity ------------------
  var listeners = [];
  function emit(evt) {
    for (var i = 0; i < listeners.length; i++) {
      try {
        listeners[i](evt);
      } catch (e) {
        /* never let a page listener break the pixel */
      }
    }
  }

  function sessionId() {
    // NOTE: Math.random is fine for a demo id; use a real UUID server-side.
    return (
      "sess_" +
      Date.now().toString(36) +
      "_" +
      Math.random().toString(36).slice(2, 8)
    );
  }

  var SESSION = {
    session_id: sessionId(),
    pixel_id: CONFIG.pixelId,
    page_url: location.href,
    referrer: document.referrer || null,
    user_agent: navigator.userAgent,
    started_at: new Date().toISOString(),
    interactions: [],
  };

  function post(path, body) {
    if (!CONFIG.endpoint) return Promise.resolve(null); // simulation mode
    return fetch(CONFIG.endpoint.replace(/\/$/, "") + path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      keepalive: true,
    })
      .then(function (r) {
        return r.ok ? r.json() : null;
      })
      .catch(function () {
        return null;
      });
  }

  // Fire a site-visit beacon on load. Your backend records the visit IP here so
  // it can later be compared to the submit IP (the "VPN problem").
  post("/visit", {
    session_id: SESSION.session_id,
    pixel_id: SESSION.pixel_id,
    page_url: SESSION.page_url,
    referrer: SESSION.referrer,
    started_at: SESSION.started_at,
  });
  emit({ type: "session_started", session: SESSION });

  // --- form instrumentation -------------------------------------------------
  function trackForm(form) {
    var fields = form.querySelectorAll("input, select, textarea");
    Array.prototype.forEach.call(fields, function (el) {
      ["focus", "blur", "change"].forEach(function (type) {
        el.addEventListener(type, function () {
          var interaction = {
            name: el.name || el.id || "(unnamed)",
            action: type,
            at: new Date().toISOString(),
          };
          SESSION.interactions.push(interaction);
          emit({ type: "field", interaction: interaction });
        });
      });
    });

    form.addEventListener("submit", function (e) {
      // Prevent the demo page from navigating away; a real integration lets the
      // form submit normally and captures in parallel.
      if (form.hasAttribute("data-pixel-demo")) e.preventDefault();

      var data = {};
      Array.prototype.forEach.call(fields, function (el) {
        if (el.name) data[el.name] = el.value;
      });

      var lead = {
        session_id: SESSION.session_id,
        pixel_id: SESSION.pixel_id,
        submitted_at: new Date().toISOString(),
        form_dwell_ms:
          Date.now() - new Date(SESSION.started_at).getTime(),
        fields: data,
      };
      emit({ type: "submitted", lead: lead });

      // Real mode: hand the lead to your Rails app and stream results back.
      // Simulation mode: fake the layer-by-layer verification so the demo works.
      if (CONFIG.endpoint) {
        post("/leads", lead).then(function (res) {
          if (res && res.lead_id && res.activity_token) {
            subscribeToActivity(res.lead_id, res.activity_token);
          } else {
            emit({ type: "info", message: "Lead submission failed or was rejected." });
          }
        });
      } else {
        simulateVerification(lead);
      }
    });
  }

  // Real transport: Server-Sent Events. The activity_token (NOT the bare
  // lead_id) is what authorizes this subscription. Lead_ids are guessable
  // and this endpoint has no session, so the token is the actual capability
  // check on the server. EventSource only does GET, so the token travels as
  // a query param over HTTPS in production.
  function subscribeToActivity(leadId, activityToken) {
    emit({ type: "info", message: "Subscribed to activity for " + leadId });
    if (!CONFIG.endpoint || typeof EventSource === "undefined") return;

    var url =
      CONFIG.endpoint.replace(/\/$/, "") +
      "/leads/" +
      encodeURIComponent(leadId) +
      "/activity?token=" +
      encodeURIComponent(activityToken);
    var source = new EventSource(url);

    source.addEventListener("layer_result", function (evt) {
      var data = JSON.parse(evt.data);
      var described = describeLayerResult(data.layer, data.state, data.data);
      emit({ type: "layer_result", layer: data.layer, verdict: described.verdict, detail: described.detail });
    });

    source.addEventListener("final_verdict", function (evt) {
      var data = JSON.parse(evt.data);
      emit({
        type: "final_verdict",
        verdict: data.verdict,
        score: data.score,
        reasons: data.reasons || [],
      });
      source.close();
    });

    source.onerror = function () {
      // The server closes the connection normally right after final_verdict;
      // EventSource treats any close as an error and would otherwise retry
      // forever, so give up once nothing more is expected.
      if (source.readyState === EventSource.CLOSED) return;
    };
  }

  // Purely cosmetic: turns the backend's real per-layer state/data into the
  // pass/warn/fail/skip vocabulary the demo panel already knows how to
  // render. The verdict that actually matters (ACCEPT/REVIEW/REJECT) is
  // computed server-side and never re-derived here.
  function describeLayerResult(layer, state, data) {
    if (state === "not_enabled") return { verdict: "skip", detail: "not enabled for this account" };
    if (state === "not_applicable") return { verdict: "skip", detail: "not applicable to this lead" };
    if (state === "skipped_insufficient_credits") return { verdict: "warn", detail: "skipped — insufficient credits" };

    data = data || {};
    switch (layer) {
      case "vpn_proxy":
        var risky = data.is_vpn || data.is_proxy || data.is_tor || data.is_datacenter || data.site_visit_ip_matches_submit_ip === false;
        return { verdict: risky ? "fail" : "pass", detail: "risk: " + (data.risk || "unknown") };
      case "anura":
        return { verdict: data.result === "good" ? "pass" : data.result === "suspect" ? "warn" : "fail", detail: "result: " + data.result };
      case "trustedform":
        return {
          verdict: data.status === "verified" ? "pass" : data.status === "not_found" ? "warn" : "fail",
          detail: "status: " + data.status,
        };
      case "blacklist_alliance":
        return {
          verdict: data.status === "clean" ? "pass" : data.status === "suspected" ? "warn" : "fail",
          detail: "status: " + data.status,
        };
      case "dnc":
        return { verdict: data.dnc_status === "callable" ? "pass" : "fail", detail: "status: " + data.dnc_status };
      case "phone_validation":
        var pValues = Object.keys(data.providers || {}).map(function (k) { return data.providers[k].valid; });
        var pAgree = pValues.every(function (v) { return v === pValues[0]; });
        return { verdict: !pAgree ? "warn" : pValues[0] ? "pass" : "fail", detail: pAgree ? "providers agree" : "providers disagree" };
      case "email_validation":
        var eValues = Object.keys(data.providers || {}).map(function (k) { return data.providers[k].deliverable; });
        var eAgree = eValues.every(function (v) { return v === eValues[0]; });
        return { verdict: !eAgree ? "warn" : eValues[0] ? "pass" : "fail", detail: eAgree ? "providers agree" : "providers disagree" };
      case "enrichment":
        var a = data.audiencelabs || {}, b = data.bytemine || {};
        if (a.match_to_lead !== b.match_to_lead) return { verdict: "warn", detail: "sources disagree" };
        return { verdict: a.match_to_lead ? "pass" : "warn", detail: a.match_to_lead ? "sources agree, identity matches" : "no source matched" };
      case "duplicate_detection":
        return {
          verdict: data.match_type === "exact" ? "fail" : data.match_type === "none" ? "pass" : "warn",
          detail: "match: " + data.match_type,
        };
      case "voice":
        return { verdict: data.verdict === "human_unique" ? "pass" : "fail", detail: "verdict: " + data.verdict };
      default:
        return { verdict: "pass", detail: "" };
    }
  }

  // ---- SIMULATION FALLBACK (used only when no data-endpoint is set) --------
  function simulateVerification(lead) {
    var demo = {
      vpn_proxy: { verdict: "pass", detail: "residential IP, submit matches visit" },
      anura: { verdict: "pass", detail: "result: good" },
      trustedform: { verdict: "pass", detail: "cert verified, phone+email match" },
      blacklist_alliance: { verdict: "pass", detail: "no litigator match" },
      dnc: { verdict: "pass", detail: "callable, window open" },
      phone_validation: { verdict: "pass", detail: "3/3 providers valid mobile" },
      email_validation: { verdict: "pass", detail: "2/2 deliverable" },
      enrichment: { verdict: "pass", detail: "2 sources agree, identity matches" },
      duplicate_detection: { verdict: "pass", detail: "no CRM match for account" },
      voice: { verdict: "skip", detail: "no voice sample" },
    };
    var order = CONFIG.layers.filter(function (l) {
      return l !== "consensus";
    });
    var i = 0;
    (function step() {
      if (i >= order.length) {
        emit({
          type: "final_verdict",
          verdict: "ACCEPT",
          score: 0.94,
          reasons: ["all layers passed", "strong consensus"],
        });
        return;
      }
      var layer = order[i++];
      var r = demo[layer] || { verdict: "pass", detail: "" };
      emit({ type: "layer_result", layer: layer, verdict: r.verdict, detail: r.detail });
      setTimeout(step, 420 + Math.random() * 380);
    })();
  }

  // --- public API -----------------------------------------------------------
  window.SuperPixel = {
    config: CONFIG,
    session: SESSION,
    onActivity: function (fn) {
      listeners.push(fn);
    },
    attach: trackForm,
  };

  // Auto-attach to any form marked data-pixel-form once the DOM is ready.
  function boot() {
    var forms = document.querySelectorAll("form[data-pixel-form]");
    Array.prototype.forEach.call(forms, trackForm);
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
