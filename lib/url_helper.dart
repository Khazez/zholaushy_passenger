import 'package:url_launcher/url_launcher.dart';

/// Кросс-платформенная замена dart:html window.open — открывает URL
/// (в т.ч. tel:) во внешнем приложении/браузере.
void openUrl(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
