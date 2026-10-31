// Supabase → Project Settings → API থেকে এই দুটো মান কপি করে বসান।
// anon public key গোপন নয় (RLS দিয়ে সুরক্ষিত), তাই GitHub-এ থাকলে সমস্যা নেই।
// কখনোই "service_role" key এখানে বসাবেন না।
window.CFG = {
  url: 'YOUR_SUPABASE_URL',
  key: 'YOUR_SUPABASE_ANON_KEY'
};
