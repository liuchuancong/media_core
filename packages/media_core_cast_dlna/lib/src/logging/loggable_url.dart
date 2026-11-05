/// Strip query/fragment from a media URL before logging it: cast URLs
/// carry the media server's access token (§22.3), and tokens never
/// belong in logs.
String loggableUrl(Uri url) {
  final withoutQuery = url.removeFragment().replace(query: '');
  var text = withoutQuery.toString();
  if (text.endsWith('?')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}
