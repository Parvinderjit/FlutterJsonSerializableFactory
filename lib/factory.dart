import 'dart:io';

// import 'package:app/builder.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:source_gen/src/generator.dart';
import 'package:glob/glob.dart';

Builder metadataLibraryBuilder(BuilderOptions options) =>
    ExportLocatingBuilder();

Builder exportBuilder(BuilderOptions options) => ExportsBuilder();

// class MBuilder extends LibraryBuilder {
//   final glob = Glob("gen/factory.m.dart");
//   MBuilder(Generator generator) : super(generator);
//   @override
//   Map<String, List<String>> get buildExtensions => {
//         r'$lib$': ["g.dart"]
//       };
//   @override
//   Future build(BuildStep buildStep) async {
//     final exports = buildStep.findAssets(Glob('**/*.dart'));
//     final content = [
//       await for (var exportLibrary in exports)
//         'export \'${exportLibrary.changeExtension('.dart').uri}\' '
//             'show ${await buildStep.readAsString(exportLibrary)}\n\n\n\n\n//----------;',
//     ];
//     if (content.isNotEmpty) {
//       buildStep.writeAsString(AssetId(buildStep.inputId.package, 'lib/g.dart'),
//           'Content : ---------\n' + content.join('\n') + '\n\n\n-------------');
//     }
//   }
// }

class ExportsBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['gen/json_factory.g.dart']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final exports = buildStep.findAssets(Glob('**/*.exports'));
    final builder = StringBuffer('''
    T? map<T extends Object>(Map map) {
      final Map map = {
    ''');

    final importBuffer = StringBuffer();

    await for (var exportLibrary in exports) {
      if (exportLibrary.path.contains('import')) {
        importBuffer.write(await buildStep.readAsString(exportLibrary));
      } else {
        builder.write(await buildStep.readAsString(exportLibrary));
      }
    }
    builder.write(''' 
      }
      return map[T]?.call(map)
    }
    ''');
    if (builder.isNotEmpty) {
      buildStep.writeAsString(
        AssetId(buildStep.inputId.package, 'lib/gen/json_factory.g.dart'),
        importBuffer.toString() + "\n" + builder.toString(),
      );
    }
  }
}

class ExportLocatingBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.dart': ['.exports', '.import.exports']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final lib = LibraryReader(await buildStep.inputLibrary);
    final exportAnnotation = TypeChecker.fromRuntime(Ann);
    var index = 0;
    final buffer = StringBuffer("");
    final import = "import '${buildStep.inputId.uri.toString()}';\n";

    for (var element in lib.annotatedWith(exportAnnotation)) {
      buffer.write(
          "${element.element.name} : (Map map) => ${element.element.name}.fromJson(map),\n");
      index++;
    }
    // buffer.write("}");
    if (index > 0) {
      buildStep.writeAsString(
          buildStep.inputId.changeExtension('.exports'), buffer.toString());
      buildStep.writeAsString(
          buildStep.inputId.changeExtension('.import.exports'), import);
    }
  }
}

class Ann {
  const Ann();
}
