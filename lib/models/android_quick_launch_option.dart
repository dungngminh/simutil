enum AndroidQuickLaunchOption {
  normal(label: 'Normal', args: []),

  coldBoot(label: 'Cold Boot', args: ['-no-snapshot-load']),

  noAudio(label: 'No Audio', args: ['-no-audio']),

  coldBootNoAudio(
    label: 'Cold Boot + No Audio',
    args: ['-no-snapshot-load', '-no-audio'],
  );

  final String label;
  final List<String> args;

  const AndroidQuickLaunchOption({required this.label, this.args = const []});
}
