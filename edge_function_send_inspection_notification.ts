// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Embedded Firebase Service Account Credentials for firesight-pushnotif
const DEFAULT_FIREBASE_SERVICE_ACCOUNT = {
  type: "service_account",
  project_id: "firesight-pushnotif",
  private_key_id: "263cf2264d1ad14dacbc2cd5aa713a8ac07f648e",
  private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCy0F3+IAcx07wD\n1taK1A2ktrRiOp6E7xGj/LHDg+lqKxwD7yIxhw3bgM1OGyO8w8zUJfYcjXqdOv4T\nDeOHU6N8Xih8tsqhqBDQI/NuKRypqiLkpIUkrjSHwGjlhZHDQdPW7KmiQYqmRgv9\nKIjYd22g6SURl3mOMW4KdeR91KGf88m8W8mmyEB075vCXKwZ/CMC6mPv7lrvdPU/\neXhoPRlytIPQOLQgMcCr/vEbUD1jA0ELWq1/XYOrNW58gxUEv6uM61CwQ5MSvWsW\nHLRGoKa/n5ZX/pLlJDr90ZT35hGnh8kBe6alGI6AkziyNycAODb0nhqFasG+MSKt\nA5FjStV7AgMBAAECggEAQyJ7H6Wrvdfmj7RyAVaDNtPH3tduW6+cemqt3R+iG5PK\n5Wk7d8fieoadzlTfMoh61y3XfLnbjruu172PrufGijOZ1NUWN+JvSY4t3668zbCM\ngDaKrI5hN5SUbZQb+Wi2HcvmFn6wDSRgbPByjH8uYEsYeUXbQ/kn/PJtUpbqBbCz\ndzozZmpvN5+3NXK2noRvG1hpUy4REJ9xIt0+hfAdeY8cstEpnKdmDc+iWg6hH9Lq\nEmAgYUKcscHOqzvkw7PflXFoQ8sw/CXYLnuMPXU4U58ukuEPvSedbJMOuTg3vB3O\nxPY3zpPoqbO1tTEbFvXSqB8e7qBKkWuTk4/tASPncQKBgQDmLmCD/cOWW8VmaX3+\ncUWD8xP56px55bOWf2zyfl7FH9imeQOqCPHI8W/WhyAh2/bUwtHez7vjFHb/zvAQ\n51LMFinLNHsxPKwDY/suDzxzuui7NACiW97h1e4H0F0SEkg6luO6gkb2QgbNEE+F\nzB5O6Yfvp5H83MhsTufb8ZBNEQKBgQDG3vyaPrca6QKEqA/iW+dqZ0Yp5Mgqs/Ji\n/0LAN3dy1lnkl9WM9NvXRqOOhrb278AlVZBGYHyivm47hS9CxeoQOu1DfNwrA1fy\neUe3OFFat5qHUusoqMgOHRw+8CorgtvCuHgGjelxm3WK5zl99sD9uJLIbhqC088s\nOYWcuSYpywKBgA7o0B2ckU+q8BVbHeseQSdz1kZo2OvYYhKMfG0UnGTeVDUsP32D\nCM5APUNDC2TGD63mVJu/Dud9itu09r3Rjf5kLR7ZbmVZDbdGgZ2RJRRF9g8yJhxe\nIQi1x64/49do0b7hySxqhdgrnK8psEz1VL09yS1PyFf9oQnK7p/DfNpRAoGBAKNR\nqwcNLBiIdQ32ax0NNq42Y/OxtAUFxLAyS2JJ6um/SRGm87SPvh88HsPEtGt1F0pR\ny2tQf+qzExoEVXyzxnZPvlwnJTSZyVcS7Kd2M7GZiOlLWl4Ixkp486JoX2leTRXL\nop5XWvh2oABTxe5Bf9qeAsVhTppUUhZSovzDPKkjAoGBAIAUQC5vQPUi3Af3jCCj\nnj1eI8GQEjCqmVaSGiEitCTWrjeOiSoYrKOHpiwRVGwJ35rowHehVisXraNSc1wR\nfe23X/PFaMKRPvH1rUMGa1RN5p0tJg9ZkuwmHyfpQ4fyDDDMko1TlyMacUQ9YMrv\nwD1LwQfiv6eBUyy3O4bc+fVV\n-----END PRIVATE KEY-----\n",
  client_email: "firebase-adminsdk-fbsvc@firesight-pushnotif.iam.gserviceaccount.com",
};

// Base64URL helper
function base64UrlEncode(data: Uint8Array | string): string {
  let base64 = "";
  if (typeof data === "string") {
    base64 = btoa(data);
  } else {
    let binary = "";
    const len = data.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(data[i]);
    }
    base64 = btoa(binary);
  }
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Convert PEM PKCS#8 private key to ArrayBuffer
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN [A-Z ]+-----/g, "")
    .replace(/-----END [A-Z ]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const buffer = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    buffer[i] = raw.charCodeAt(i);
  }
  return buffer.buffer;
}

// Generate Google OAuth2 Access Token from Service Account JSON
async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaims = base64UrlEncode(JSON.stringify(claims));
  const unsignedToken = `${encodedHeader}.${encodedClaims}`;

  const binaryKey = pemToArrayBuffer(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signedJwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  // Request OAuth access token from Google
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to obtain Google access token: ${errorText}`);
  }

  const tokenData = await response.json();
  return tokenData.access_token;
}

serve(async (req) => {
  // 1. Handle CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // 2. Parse request payload (Supports both direct call and Supabase Webhook)
    const body = await req.json();

    let inspectionId = body.inspectionId || body.inspection_id;
    let inspectorId = body.inspectorId || body.inspector_id;
    let businessName = body.businessName || body.business_name;
    let orderNo = body.orderNo || body.inspection_order_no;
    let address = body.address;

    // Handle Supabase Database Webhook payload format
    if (body.record) {
      inspectionId = body.record.id;
      inspectorId = body.record.inspector_id;
      businessName = body.record.business_name;
      orderNo = body.record.inspection_order_no;
      address = body.record.address;
    }

    if (!inspectorId) {
      return new Response(
        JSON.stringify({ error: "No inspector_id provided in payload." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Fetch inspector profile to retrieve FCM push token and name
    const { data: inspectorProfile, error: profileErr } = await supabaseAdmin
      .from("profiles")
      .select("id, full_name, role, fcm_token")
      .eq("id", inspectorId)
      .maybeSingle();

    if (profileErr) {
      console.error("Error fetching inspector profile:", profileErr);
    }

    const inspectorName = inspectorProfile?.full_name || "Inspector";
    const fcmToken = inspectorProfile?.fcm_token;

    const notifTitle = "🚨 New Inspection Scheduled";
    const notifBody = `Officer assigned you to inspect ${businessName || "an establishment"} (Order: ${orderNo || "N/A"}).`;

    // 4. Record In-App Notification in public.notifications table (non-blocking)
    try {
      const { error: notifInsertErr } = await supabaseAdmin.from("notifications").insert([
        {
          user_id: inspectorId,
          title: notifTitle,
          body: notifBody,
          type: "inspection_scheduled",
          data: {
            inspection_id: inspectionId,
            order_no: orderNo,
            business_name: businessName,
            address: address,
          },
        },
      ]);

      if (notifInsertErr) {
        console.warn("Notice: In-app notification insert:", notifInsertErr.message);
      }
    } catch (dbErr: any) {
      console.warn("Notice: Notifications table insert note:", dbErr?.message);
    }

    // 5. Send FCM Push Notification using Service Account Credentials
    let fcmResult = { sent: false, note: "No FCM token for inspector" };

    const firebaseServiceAccountEnv = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    const serviceAccount = firebaseServiceAccountEnv
      ? JSON.parse(firebaseServiceAccountEnv)
      : DEFAULT_FIREBASE_SERVICE_ACCOUNT;

    if (!fcmToken) {
      fcmResult = {
        sent: false,
        note: `Inspector ${inspectorName} has not logged in on mobile yet to register an FCM push token. In-app notification was stored.`,
      };
    } else {
      try {
        const accessToken = await getGoogleAccessToken(serviceAccount);

        const fcmPayload = {
          message: {
            token: fcmToken,
            notification: {
              title: notifTitle,
              body: notifBody,
            },
            data: {
              inspection_id: String(inspectionId || ""),
              order_no: String(orderNo || ""),
              business_name: String(businessName || ""),
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: "high",
              notification: {
                channel_id: "high_importance_channel",
                sound: "default",
                priority: "high",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
          },
        };

        const fcmRes = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        if (!fcmRes.ok) {
          const fcmErrText = await fcmRes.text();
          console.error("FCM API error response:", fcmErrText);
          fcmResult = { sent: false, note: `FCM Error: ${fcmErrText}` };
        } else {
          const fcmData = await fcmRes.json();
          fcmResult = { sent: true, note: fcmData.name };
        }
      } catch (err: any) {
        console.error("Exception sending FCM push:", err);
        fcmResult = { sent: false, note: err?.message || "Failed to dispatch FCM message." };
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        inspectorId: inspectorId,
        inspectorName: inspectorName,
        fcm: fcmResult,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (err: any) {
    console.error("Edge function error:", err);
    return new Response(
      JSON.stringify({ error: err?.message || "Internal server error" }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
