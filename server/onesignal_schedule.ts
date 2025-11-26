import fetch from 'node-fetch';

const ONE_SIGNAL_APP_ID = process.env.ONE_SIGNAL_APP_ID!;
const ONE_SIGNAL_REST_API_KEY = process.env.ONE_SIGNAL_REST_API_KEY!;

async function sendSegmented(language: string, title: string, message: string) {
  const res = await fetch('https://api.onesignal.com/notifications', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${ONE_SIGNAL_REST_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      app_id: ONE_SIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
      filters: [
        { field: 'tag', key: 'language', relation: '=', value: language }
      ],
      // Schedule example: 10:00 user device timezone
      send_after: new Date().toISOString(),
      delivery_time_of_day: '10:00AM',
    })
  });
  if (!res.ok) {
    console.error('OneSignal error', await res.text());
  }
}

async function main() {
  await sendSegmented('tr', 'Sabah Tavsiyesi', 'Bugün Fanny’yi mi counterlamak istiyorsun?');
  await sendSegmented('en', 'Morning Tip', 'Counter Fanny today? Get a quick hero suggestion.');
}

main().catch(console.error);

