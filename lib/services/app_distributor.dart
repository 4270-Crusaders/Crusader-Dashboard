const bool isWPILib = bool.fromEnvironment('ELASTIC_WPILIB');

const String logoPath = 'assets/logos/logo.png';

const String appTitle = !isWPILib ? 'Rebuilt Dashboard' : 'Rebuilt Dashboard (WPILib)';
