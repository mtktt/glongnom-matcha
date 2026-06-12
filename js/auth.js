// Auth helper — wraps Supabase Auth + user_profiles role lookup

const Auth = (() => {

  // Sign in with email + password
  async function signIn(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  }

  // Sign out and redirect to login
  async function signOut() {
    await supabase.auth.signOut();
    window.location.href = '/login.html';
  }

  // Returns the current Supabase session (null if not logged in)
  async function getSession() {
    const { data } = await supabase.auth.getSession();
    return data.session;
  }

  // Returns the user_profiles row for the current user (includes role)
  async function getProfile() {
    const session = await getSession();
    if (!session) return null;

    const { data, error } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('id', session.user.id)
      .single();

    if (error) return null;
    return data;
  }

  // Guard: redirects to login if not authenticated.
  // Optionally pass allowedRoles array to enforce role-based access.
  // Usage: await Auth.require(['admin', 'manager'])
  async function require(allowedRoles = null) {
    const session = await getSession();
    if (!session) {
      window.location.href = '/login.html';
      return null;
    }

    if (allowedRoles) {
      const profile = await getProfile();
      if (!profile || !allowedRoles.includes(profile.role)) {
        window.location.href = '/login.html';
        return null;
      }
      return profile;
    }

    return await getProfile();
  }

  // Redirect logged-in users away from login page
  async function redirectIfLoggedIn(destination = '/admin/') {
    const session = await getSession();
    if (session) window.location.href = destination;
  }

  return { signIn, signOut, getSession, getProfile, require, redirectIfLoggedIn };
})();
