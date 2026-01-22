
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";
import * as jose from "https://deno.land/x/jose@v4.13.1/index.ts";

// Service Account Credentials (Hardcoded for immediate deployment)
const SERVICE_ACCOUNT = {
  "type": "service_account",
  "project_id": "atmetny",
  "private_key_id": "c5b3136cf41e925579891035eeef5a4627375245",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQC11mcOt4OsFmW1\nhciBFClXr5AHKIdvUvdWdK/VDRMEzP/svuIj5B5aUxovJ8CArMLHuxriOXR9vtjh\nZvsgDOBG8sPNoMybD6l4/ytz4CL/Io48G8kPqEyiExEKwk10Ik+JcRyGSbm1ArAL\nwKgxFEE+zPk8CidScsS/7hladsR5JZdNvTtntaPWHopADiQ/Pf08hGMZ5OPxbKFS\nQFnloRwCrfV/KLak2mmdPgv2benb8HODTVrIoLrshmJztJZoIxxxELH4mUy8CMfY\nJKrvxsePUz5mwVC8Jif8jFa5D/rlB//bRbrt/2Zl8Xyl8gwZInGAsPf9tudLwxFL\nQ8p7uIjLAgMBAAECggEAD2vNdawOmKuVmJ1t8bR6BRu4hULkqYZJv6VJvDHNqRyR\nn8xYdV7FTDe8Ar/GTaNZKYMutnzU6k0jK4qGRaOR6bJw9KFseMINR1usnbkmfqi5\nk1Nv68oEJcKkMVtlIjI+uJNFLgZWn4lI0NZX7UGgfuj3QiZCS3W8ReK1d7yW0QdA\nfOxA1SNu0Ql6nqmB+4+w+X/61U2GXiSJEjNBCkrh/JJJ+dWIZJlyrk37syd+cdA1\ngMa/yi8w61lY3ThVFqXkBmYTzayXD41b3Yh1SUjuQQsiZkyu9cX7x59MYvdaWOsT\n1lBHXUpQNbnUPx3e/0CDYJKVyxX6Sgv0gWbL5PVD4QKBgQDfypI+pQ6WOuQ0HXPg\neD9lad2A+N7kKEmGEbaz/yeR2YD+iw+RwNagBkt4UVhJPFBPTkVBK01xNr4/LbIN\nPjn21XELO9IEe1q20FlBGktFaDzROPZsNDibf3zw8zIrvHcWy118Lr2G+zWZEud4\n7D1vMDJh4tIauUMGFhyX6r2sKQKBgQDQAhMMLB37QMDBK+aaItpF90V/aPPGUYZD\nYd61lNxHZjz33nkHrsbt/Pw/w4VjBwutJLcCQ+ydsrrFSRY8MuSxtVH8PFiFUkFk\ncxlPCfsF4nyc1KnDh/oBaAHbB2AZBpm4FScV3avs3VQp6Pu9Cbo8k3eRg6TloKzh\naj7/LMrr0wKBgQCKwtRDO5z70bBGEC0Vdfn5K9dIbQfneIN+OeWLXh5u9Opi6l7R\nBT0PJFgPVoDjiB5Tzjhq3Cq8lDEKg47vXzIZtubNDF6AoOvyhuWQ1HjvpF5xbFx/\nYzHmWPpjfKgTLly5KYfhxCmIVKM7MtmLxQ+ircPPphCYuV6xm2xHViodYQKBgQCo\nQUVPD1ChMFu65dv+yjptZfsdeLPXs5I7ZytTDjqwto6Soa6c/E+FqqIQogN/eu+C\n+rPebTs0xKI3e0s1HqXG6biLo/Smw0aKDmBmgtg+hlnuMkewFomwIYV+upSNKb2m\nHdYj5c9wJggybndTDk9LOK37UtVLuZCeNecHWiA6aQKBgQC2UPzoGpUxRe6EHdd2\nMZJPJ7Bstco5eN+6UDnesDReS1Qa0jKgmuI5jwx1EeNKp/GQLGRwMlxjxsR7IXX7\ncyzAfEKAcXElJhNZlaHiYIMilAER9ZvmAEN0FrYwC/KQ4tUU1rneJEY7xbNhhAzJ\npUkDBY7UJNTayF1jCJSIrqcIog==\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@atmetny.iam.gserviceaccount.com",
  "client_id": "104872393607946727456",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40atmetny.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
};

// Supabase environment variables are still needed for database connection
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Helper to get Google Access Token using Service Account
async function getAccessToken({ client_email, private_key }: any) {
  const alg = "RS256";
  const pkcs8 = private_key.replace(/\\n/g, "\n");
  const privateKey = await jose.importPKCS8(pkcs8, alg);

  const jwt = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg })
    .setIssuer(client_email)
    .setSubject(client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await res.json();
  return data.access_token;
}

serve(async (req) => {
  try {
    // 1. Parse Request (Webhook Payload)
    const payload = await req.json();
    const { record, type } = payload;

    // Only allow INSERT events
    if (type !== "INSERT") {
      return new Response("Skipped: Not an INSERT event", { status: 200 });
    }

    if (!record) {
      return new Response("Error: No record data", { status: 400 });
    }

    console.log("🔔 New Notification Request:", record.id);

    // 2. Prepare Firebase Credentials
    const accessToken = await getAccessToken(SERVICE_ACCOUNT);

    // 3. Determine Targets (Tokens or Topic)
    let messageBody: any = {
      notification: {
        title: record.title,
        body: record.body,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: record.notification_type,
        target_id: record.target_id || "",
      },
    };

    if (record.notification_type === 'all') {
      messageBody.topic = 'all_users';
    } else if (record.notification_type === 'user' && record.target_id) {
       // Fetch user's FCM token
       const { data: userData, error: userError } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', record.target_id)
        .single();
      
      if (userError || !userData?.fcm_token) {
        console.log(`⚠️ User ${record.target_id} has no FCM token.`);
        return new Response("Skipped: User has no token", { status: 200 });
      }
      messageBody.token = userData.fcm_token;

    } else if (record.notification_type === 'course' && record.target_id) {
        messageBody.topic = `course_${record.target_id}`;
    } else {
        return new Response("Skipped: Invalid target", { status: 400 });
    }

    // 4. Send to FCM
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${SERVICE_ACCOUNT.project_id}/messages:send`;
    
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: messageBody }),
    });

    const result = await response.json();
    console.log("✅ FCM Response:", result);

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("❌ Error sending push:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
