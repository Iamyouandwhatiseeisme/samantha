import 'package:highlight/highlight.dart' show highlight;
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/diff.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/graphql.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

void registerHighlightLanguages() {
  highlight.registerLanguage('dart', dart);
  highlight.registerLanguage('python', python);
  highlight.registerLanguage('bash', bash);
  highlight.registerLanguage('javascript', javascript);
  highlight.registerLanguage('typescript', typescript);
  highlight.registerLanguage('json', json);
  highlight.registerLanguage('yaml', yaml);
  highlight.registerLanguage('xml', xml);
  highlight.registerLanguage('css', css);
  highlight.registerLanguage('sql', sql);
  highlight.registerLanguage('rust', rust);
  highlight.registerLanguage('go', go);
  highlight.registerLanguage('java', java);
  highlight.registerLanguage('kotlin', kotlin);
  highlight.registerLanguage('swift', swift);
  highlight.registerLanguage('cpp', cpp);
  highlight.registerLanguage('diff', diff);
  highlight.registerLanguage('markdown', markdown);
  highlight.registerLanguage('graphql', graphql);
  highlight.registerLanguage('plaintext', plaintext);
}

String resolveLanguage(String? label) {
  if (label == null || label.isEmpty) return '';
  return switch (label.toLowerCase()) {
    'sh' || 'shell' || 'zsh' || 'fish' => 'bash',
    'py' || 'python3' => 'python',
    'js' || 'jsx' || 'node' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'yml' => 'yaml',
    'html' || 'svg' || 'mathml' => 'xml',
    'golang' => 'go',
    'c++' || 'cxx' || 'c' || 'h' || 'hpp' || 'hxx' => 'cpp',
    'kt' || 'kts' => 'kotlin',
    'rs' => 'rust',
    'md' || 'mdx' => 'markdown',
    'gql' => 'graphql',
    _ => label.toLowerCase(),
  };
}
