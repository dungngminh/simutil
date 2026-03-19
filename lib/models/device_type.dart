enum DeviceType {
  physical,
  
  simulator;

  bool get isPhysical => this == DeviceType.physical;
  
  bool get isSimulator => this == DeviceType.simulator;
}
