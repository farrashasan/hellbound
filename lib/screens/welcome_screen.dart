part of '../hellbound.dart';

extension _WelcomeScreen on _HellboundState {
  Widget welcome() => Column(
    children: [
      const SizedBox(height: 40),
      const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'HELL',
              style: TextStyle(color: HellboundColors.accent),
            ),
            TextSpan(text: 'BOUND'),
          ],
        ),
        style: TextStyle(
          fontSize: 27,
          letterSpacing: 4,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 52),
      mascot('grin', 190),
      const SizedBox(height: 36),
      Text(
        'Welcome to\nHellbound.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 16),
      const Text('Make promises. Keep them. Or else.'),
      const SizedBox(height: 64),
      SizedBox(
        width: double.infinity,
        child: button('Get Started', () => go('register')),
      ),
      TextButton(
        onPressed: () => go('login'),
        child: const Text('Already have an account? Log In'),
      ),
    ],
  );
}
