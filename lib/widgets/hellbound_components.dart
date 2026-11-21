part of '../hellbound.dart';

extension _HellboundComponents on _HellboundState {
  Widget mascot(String mood, [double size = 110]) => Image.asset(
    'assets/mascot_v2/$mood.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'Hellbound demon mascot',
  );

  Widget title(String text, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(text, style: Theme.of(context).textTheme.headlineMedium),
      if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle)],
      const SizedBox(height: 24),
    ],
  );

  Widget panel(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HellboundColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HellboundColors.outline.withValues(alpha: .3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget button(String label, VoidCallback action, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: secondary
            ? OutlinedButton(onPressed: action, child: Text(label))
            : FilledButton(onPressed: action, child: Text(label)),
      );

  Widget label(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: HellboundColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget field(
    String label,
    TextEditingController controller, {
    bool secret = false,
    int lines = 1,
    String? Function(String?)? validator,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      obscureText: secret && obscure,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        suffixIcon: secret
            ? IconButton(
                tooltip: 'Toggle password',
                onPressed: () => refresh(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
    ),
  );

  Widget pactCard(Pact p) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: HellboundColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => open(p),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                p.status,
                style: const TextStyle(
                  color: HellboundColors.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Text('${p.responsible} responsible · Verifier ${p.verifier}'),
              const SizedBox(height: 8),
              Text(date(p.deadline)),
            ],
          ),
        ),
      ),
    ),
  );
}
