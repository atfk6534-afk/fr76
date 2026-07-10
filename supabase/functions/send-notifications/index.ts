import { serve } from "https://deno.land/std/http/server.ts";

const PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")!.replace(/\\n/g, "\n");

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);

  const jwtHeader = {
    alg: "RS256",
    typ: "JWT",
  };

  const jwtClaim = {
    iss: CLIENT_EMAIL,
    scope:
      "https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const enc = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const unsigned = `${enc(jwtHeader)}.${enc(jwtClaim)}`;

  const binaryKey = Uint8Array.from(
    atob(
      PRIVATE_KEY.replace(
        /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g,
        ""
      )
    ),
    (c) => c.charCodeAt(0)
  );

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned)
  );

  const jwt =
    unsigned +
    "." +
    btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body:
      "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" + jwt,
  });

  return (await res.json()).access_token;
}

serve(async () => {
  try {
    const accessToken = await getAccessToken();

    const query = await fetch(
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          structuredQuery: {
            from: [{ collectionId: "notifications" }],
            where: {
              fieldFilter: {
                field: { fieldPath: "sent" },
                op: "EQUAL",
                value: {
                  booleanValue: false,
                },
              },
            },
          },
        }),
      }
    );

    const docs = await query.json();

    let sent = 0;

    for (const row of docs) {
      if (!row.document) continue;

      const doc = row.document;

      const fields = doc.fields;

      const title = fields.title.stringValue;
      const body = fields.body.stringValue;
      const uid = fields.toUid.stringValue;

      const user = await fetch(
        `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users/${uid}`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      const userData = await user.json();

      const token = userData.fields?.fcmToken?.stringValue;

      if (!token) continue;

      await fetch(
        `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification: {
                title,
                body,
              },
            },
          }),
        }
      );

      await fetch(doc.name, {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          fields: {
            sent: {
              booleanValue: true,
            },
          },
        }),
      });

      sent++;
    }

    return new Response(JSON.stringify({ sent }), {
      headers: {
        "Content-Type": "application/json",
      },
    });
  } catch (e) {
    return new Response(String(e), {
      status: 500,
    });
  }
});
