part of '../hellbound.dart';

extension _AuthScreen on _HellboundState {
  Widget authentication() {
    final registering = page == 'register';
    return Form(
      key: authKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: mascot('happy')),
          title(
            registering ? 'Sign your soul away.' : 'Welcome back.',
            registering
                ? 'Just the basics. We promise.'
                : 'The Demon missed you.',
          ),
          if (registering)
            field(
              'Username',
              username,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Username is required' : null,
            ),
          field(
            'Email',
            mail,
            errorText: registering ? registrationEmailError : loginEmailError,
            onChanged: (_) {
              clearLoginError();
              clearRegistrationEmailError();
            },
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                ? null
                : 'Enter a valid email',
          ),
          field(
            'Password',
            password,
            secret: true,
            errorText: registering ? null : loginError,
            onChanged: (_) => clearLoginError(),
            validator: (v) => (v ?? '').length < 6
                ? 'Password needs at least 6 characters'
                : null,
          ),
          if (registering)
            field(
              'Confirm Password',
              confirm,
              secret: true,
              validator: (v) =>
                  v != password.text ? 'Passwords do not match' : null,
            ),
          button(
            registering ? 'Create Account' : 'Log In',
            () => authenticate(registering),
          ),
          TextButton(
            onPressed: () => go(registering ? 'login' : 'register'),
            child: Text(
              registering
                  ? 'Already bound? Log In'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ),
    );
  }
}
