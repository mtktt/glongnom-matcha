// Supabase project credentials
// Replace these values after you create your Supabase project:
// Dashboard → Settings → API → Project URL + anon public key
const SUPABASE_URL  = 'https://ykxzmakquyjpsgdaalba.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlreHptYWtxdXlqcHNnZGFhbGJhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5NjY2MzksImV4cCI6MjA5NTU0MjYzOX0.jMkBNTF7qCLso33KwuYl_50YpByxy-sZHoPhn4sbIHA';

window.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);
