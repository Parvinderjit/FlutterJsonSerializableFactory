import 'dart:async';

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:glob/glob.dart';

Builder jsonPartBuilder(BuilderOptions options) => JsonPartMapper();

Builder jsonSerializerFactoryBuilder(BuilderOptions options) =>
    ExportsBuilder();

class JsonPartMapper extends Builder {
  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final lib = LibraryReader(await buildStep.inputLibrary);
    final exportAnnotation = TypeChecker.fromRuntime(JsonSerializable);
    var index = 0;
    final buffer = StringBuffer("");
    final import = "import '${buildStep.inputId.uri.toString()}';\n";
    for (var element in lib.annotatedWith(exportAnnotation)) {
      buffer.write(
          "${element.element.name} : (Map<String,dynamic> map) => ${element.element.name}.fromJson(map),\n");
      index++;
    }
    if (index > 0) {
      buildStep.writeAsString(
          buildStep.inputId.changeExtension('.method.json.part'),
          buffer.toString());
      buildStep.writeAsString(
          buildStep.inputId.changeExtension('.import.json.part'), import);
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        ".dart": [
          ".method.json.part",
          ".import.json.part",
        ]
      };
}

class ExportsBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['gen/json_serialized_factory.g.dart']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final exports = buildStep.findAssets(Glob('**/*.json.part'));
    final builder = StringBuffer('''
      final Map _map = {
    ''');

    final importBuffer = StringBuffer();
    final factoryBuffer = StringBuffer();

    await for (var exportLibrary in exports) {
      if (exportLibrary.path.contains('import')) {
        importBuffer.write(await buildStep.readAsString(exportLibrary));
      } else if (exportLibrary.package.contains(".factory")) {
        factoryBuffer.write(await buildStep.readAsString(exportLibrary));
      } else {
        builder.write(await buildStep.readAsString(exportLibrary));
      }
    }
    builder.write(''' 
    };

    abstract class JsonSerializableFactory {
      JsonSerializableFactory._();
      static T? map<T extends Object>(Map<String,dynamic> map) {
          return _map[T]?.call(map);
      }
    }
    ''');
    if (builder.isNotEmpty) {
      buildStep.writeAsString(
        AssetId(buildStep.inputId.package,
            'lib/gen/json_serialized_factory.g.dart'),
        importBuffer.toString() + "\n" + builder.toString(),
      );
    }
  }
}
