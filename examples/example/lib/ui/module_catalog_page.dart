// import 'package:flutter/material.dart';

// import '../demos/module_demo.dart';
// import '../language.dart';
// import 'module_demo_page.dart';

// /// Home page: catalog of all module demos grouped by category.
// class ModuleCatalogPage extends StatelessWidget {
//   const ModuleCatalogPage({super.key, required this.demos});

//   final List<ModuleDemo> demos;

//   @override
//   Widget build(BuildContext context) {
//     final lang = DemoLanguageScope.of(context);
//     final grouped = {
//       for (final category in ModuleCategory.values)
//         category: demos.where((d) => d.category == category).toList(),
//     };

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(lang == DemoLanguage.zh ? 'media_core 模块导览' : 'media_core Module Tour'),
//         actions: const [_LanguageToggle()],
//       ),
//       body: ListView(
//         padding: const EdgeInsets.symmetric(vertical: 8),
//         children: [
//           for (final category in ModuleCategory.values) ...<Widget>[
//             if (grouped[category]!.isEmpty) continue,
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
//               child: Text(
//                 lang == DemoLanguage.zh ? category.labelZh : category.labelEn,
//                 style: Theme.of(context).textTheme.titleMedium?.copyWith(
//                       color: Theme.of(context).colorScheme.primary,
//                       fontWeight: FontWeight.bold,
//                     ),
//               ),
//             ),
//             const Divider(height: 1),
//             for (final demo in grouped[category]!)
//               ListTile(
//                 leading: Text(demo.id,
//                     style: const TextStyle(
//                         fontFamily: 'monospace',
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600)),
//                 title: Text(lang == DemoLanguage.zh ? demo.nameZh : demo.nameEn),
//                 subtitle: Text(
//                   (lang == DemoLanguage.zh ? demo.purposeZh : demo.purposeEn),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 trailing: const Icon(Icons.chevron_right),
//                 onTap: () => Navigator.push(
//                   context,
//                   MaterialPageRoute<void>(
//                     builder: (_) => ModuleDemoPage(demo: demo),
//                   ),
//                 ),
//               ),
//           ],
//         ],
//       ),
//     );
//   }
// }

// class _LanguageToggle extends StatelessWidget {
//   const _LanguageToggle();

//   @override
//   Widget build(BuildContext context) {
//     final lang = DemoLanguageScope.of(context);
//     return Padding(
//       padding: const EdgeInsets.only(right: 12),
//       child: ActionChip(
//         avatar: const Icon(Icons.translate, size: 18),
//         label: Text(lang == DemoLanguage.zh ? 'EN' : '中文'),
//         onPressed: () => DemoLanguageScope.toggle(context),
//       ),
//     );
//   }
// }
