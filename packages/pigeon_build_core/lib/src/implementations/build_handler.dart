import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pigeon/pigeon.dart';

import 'package:pigeon_build_config/pigeon_build_config.dart';

import '../../pigeon_build_core.dart';

class PigeonBuildHandler {
  final p.Context pathContext =
      p.Context(style: Platform.isWindows ? p.Style.posix : p.Style.platform);

  BuildHandlerResult handleInput(PigeonBuildConfig config, String inputPath) {
    final nInputPath = pathContext.normalize(inputPath);
    final mainInput = config.mainInput;

    if (p.extension(nInputPath) != ".dart") {
      throw ArgumentError("Input path could be .dart file only", "inputPath");
    }

    PigeonBuildInputConfig? outInput;
    String? dartInput;
    String? dartOut;
    String? dartTestOut;
    String? objcHeaderOut;
    String? objcSourceOut;
    ObjcOptions? objcOptions;
    String? javaOut;
    JavaOptions? javaOptions;
    String? swiftOut;
    String? kotlinOut;
    KotlinOptions? kotlinOptions;
    String? cppHeaderOut;
    String? cppSourceOut;
    CppOptions? cppOptions;
    String? copyrightHeader;
    bool? oneLanguage;
    String? astOut;
    bool? debugGenerators;

    PigeonBuildInputConfig? matchingInput;
    for (var input in config.inputs) {
      if (input.input == null) {
        continue;
      }

      final currentInputPath = combinePath(input.input, mainInput?.input);

      if (currentInputPath != nInputPath) {
        continue;
      }

      matchingInput = input;
      break;
    }

    if (matchingInput != null || config.inputsInferred) {
      outInput = matchingInput;
      dartInput = nInputPath;
      copyrightHeader = matchingInput?.copyrightHeader ?? mainInput?.copyrightHeader;
      oneLanguage = matchingInput?.oneLanguage;
      debugGenerators = matchingInput?.debugGenerators;

      // this keeps the directory structure for inferred files the same as the pigeon files
      var dirPathFromBase = p.dirname(p.relative(nInputPath, from: mainInput?.input));
      PigeonBuildOutputConfig createInferredConfig(String filename) {
        return PigeonBuildOutputConfig(path: p.join(dirPathFromBase, filename));
      }

      var inputFileName = p.basenameWithoutExtension(nInputPath);
      // dart files should be in snake_case, but just in case, let's convert it anyway
      var inputFileInSnakeCase = _pascalToSnake(inputFileName);
      var inputFileInPascalCase = _snakeToPascal(inputFileInSnakeCase);
      var inputFileInLowerCase = inputFileInPascalCase.toLowerCase();
      var inputFileInUpperCase = inputFileInPascalCase.toUpperCase();

      if (matchingInput?.ast != null) {
        astOut = combineOutFilePath(
          out: matchingInput?.ast!.out,
          baseOut: mainInput?.ast?.out,
        );
      } else if (_shouldInfer(mainInput?.ast?.out, config)) {
        var astPigeonName = "$inputFileInSnakeCase.pigeon.ast";
        astOut = combineOutFilePath(
          out: createInferredConfig(astPigeonName),
          baseOut: mainInput?.ast?.out,
        );
      }

      if (matchingInput?.dart != null) {
        dartOut = combineOutFilePath(
          out: matchingInput?.dart!.out,
          baseOut: mainInput?.dart?.out,
        );
        dartTestOut = combineOutFilePath(
          out: matchingInput?.dart!.testOut,
          baseOut: mainInput?.dart?.testOut,
        );
      } else {
        if (_shouldInfer(mainInput?.dart?.out, config)) {
          var dartPigeonName = "$inputFileInSnakeCase.pigeon.dart";
          dartOut = combineOutFilePath(
            out: createInferredConfig(dartPigeonName),
            baseOut: mainInput?.dart?.out,
          );
        }
        if (_shouldInfer(mainInput?.dart?.testOut, config)) {
          var dartPigeonName = "$inputFileInSnakeCase.pigeon.dart";
          dartTestOut = combineOutFilePath(
            out: createInferredConfig(dartPigeonName),
            baseOut: mainInput?.dart?.testOut,
          );
        }
      }

      if (matchingInput?.objc != null) {
        objcHeaderOut = combineOutFilePath(
          out: matchingInput?.objc!.headerOut,
          baseOut: mainInput?.objc?.headerOut,
        );
        objcSourceOut = combineOutFilePath(
          out: matchingInput?.objc!.sourceOut,
          baseOut: mainInput?.objc?.sourceOut,
        );
      } else {
        if (_shouldInfer(mainInput?.objc?.headerOut, config)) {
          var objcHeaderPigeonName = "$inputFileInPascalCase.pigeon.h";
          objcHeaderOut = combineOutFilePath(
            out: createInferredConfig(objcHeaderPigeonName),
            baseOut: mainInput?.objc?.headerOut,
          );
        }
        if (_shouldInfer(mainInput?.objc?.sourceOut, config)) {
          var objcSourcePigeonName = "$inputFileInPascalCase.pigeon.m";
          objcSourceOut = combineOutFilePath(
            out: createInferredConfig(objcSourcePigeonName),
            baseOut: mainInput?.objc?.sourceOut,
          );
        }
      }
      if (objcHeaderOut != null || objcSourceOut != null) {
        if (mainInput?.objc?.prefix != null || matchingInput?.objc?.prefix != null) {
          var prefix = matchingInput?.objc?.prefix ?? mainInput?.objc?.prefix;
          if (config.inputsInferred) {
            prefix ??= "${inputFileInUpperCase}_";
          }
          objcOptions = ObjcOptions(
            prefix: prefix,
          );
        } else {
          objcOptions =
              ObjcOptions(); //TODO: Remove when this PR is merged https://github.com/flutter/packages/pull/4756
        }
      }

      if (matchingInput?.java != null) {
        javaOut = combineOutFilePath(
          out: matchingInput?.java!.out,
          baseOut: mainInput?.java?.out,
        );
      } else if (_shouldInfer(mainInput?.java?.out, config)) {
        var javaPigeonName = "$inputFileInPascalCase.pigeon.java";
        javaOut = combineOutFilePath(
          out: createInferredConfig(javaPigeonName),
          baseOut: mainInput?.java?.out,
        );
      }
      if (javaOut != null) {
        var package = matchingInput?.java?.package;
        if (config.inputsInferred) {
          package ??= '.$inputFileInLowerCase';
        }
        javaOptions = JavaOptions(
          package: combinePackage(
            package,
            mainInput?.java?.package,
          ),
          useGeneratedAnnotation: matchingInput?.java!.useGeneratedAnnotation,
        );
      }

      if (matchingInput?.kotlin != null) {
        kotlinOut = combineOutFilePath(
          out: matchingInput?.kotlin!.out,
          baseOut: mainInput?.kotlin?.out,
        );
      } else if (_shouldInfer(mainInput?.kotlin?.out, config)) {
        var kotlinPigeonName = "$inputFileInPascalCase.pigeon.kt";
        kotlinOut = combineOutFilePath(
          out: createInferredConfig(kotlinPigeonName),
          baseOut: mainInput?.kotlin?.out,
        );
      }
      if (kotlinOut != null) {
        var package = matchingInput?.kotlin?.package;
        if (config.inputsInferred) {
          package ??= '.$inputFileInLowerCase';
        }
        kotlinOptions = KotlinOptions(
          package: combinePackage(
            package,
            mainInput?.kotlin?.package,
          ),
        );
      }

      if (matchingInput?.swift != null) {
        swiftOut = combineOutFilePath(
          out: matchingInput?.swift!.out,
          baseOut: mainInput?.swift?.out,
        );
      } else if (_shouldInfer(mainInput?.swift?.out, config)) {
        var swiftPigeonName = "$inputFileInPascalCase.pigeon.swift";
        swiftOut = combineOutFilePath(
          out: createInferredConfig(swiftPigeonName),
          baseOut: mainInput?.swift?.out,
        );
      }

      if (matchingInput?.cpp != null) {
        cppHeaderOut = combineOutFilePath(
          out: matchingInput?.cpp!.headerOut,
          baseOut: mainInput?.cpp?.headerOut,
        );
        cppSourceOut = combineOutFilePath(
          out: matchingInput?.cpp!.sourceOut,
          baseOut: mainInput?.cpp?.sourceOut,
        );
      } else {
        if (_shouldInfer(mainInput?.cpp?.headerOut, config)) {
          var cppHeaderPigeonName = "$inputFileInSnakeCase.pigeon.h";
          cppHeaderOut = combineOutFilePath(
            out: createInferredConfig(cppHeaderPigeonName),
            baseOut: mainInput?.cpp?.headerOut,
          );
        }
        if (_shouldInfer(mainInput?.cpp?.sourceOut, config)) {
          var cppSourcePigeonName = "$inputFileInSnakeCase.pigeon.cpp";
          cppSourceOut = combineOutFilePath(
            out: createInferredConfig(cppSourcePigeonName),
            baseOut: mainInput?.cpp?.sourceOut,
          );
        }
      }
      if (cppHeaderOut != null || cppSourceOut != null) {
        if (mainInput?.cpp?.namespace != null || matchingInput?.cpp?.namespace != null) {
          var namespace = matchingInput?.cpp?.namespace ?? mainInput?.cpp?.namespace;
          if (config.inputsInferred) {
            namespace ??= "pigeon::$inputFileInLowerCase";
          }
          cppOptions = CppOptions(
            namespace: namespace,
          );
        } else {
          cppOptions =
              CppOptions(); //TODO: Remove when this PR is merged https://github.com/flutter/packages/pull/4756
        }
      }
    }

    if (outInput == null && !config.inputsInferred) {
      return createBuildHandlerResult(
        config: config,
      );
    }

    final pigeonOptions = PigeonOptions(
      input: dartInput,
      copyrightHeader: copyrightHeader,
      oneLanguage: oneLanguage,
      debugGenerators: debugGenerators,
      dartOut: dartOut,
      dartTestOut: dartTestOut,
      astOut: astOut,
      objcHeaderOut: objcHeaderOut,
      objcSourceOut: objcSourceOut,
      objcOptions: objcOptions,
      javaOut: javaOut,
      javaOptions: javaOptions,
      kotlinOut: kotlinOut,
      kotlinOptions: kotlinOptions,
      swiftOut: swiftOut,
      cppHeaderOut: cppHeaderOut,
      cppSourceOut: cppSourceOut,
      cppOptions: cppOptions,
    );

    return createBuildHandlerResult(
      config: config,
      input: outInput,
      options: pigeonOptions,
    );
  }

  BuildHandlerResult createBuildHandlerResult({
    required PigeonBuildConfig config,
    PigeonBuildInputConfig? input,
    PigeonOptions? options,
  }) {
    return BuildHandlerResult(
      config: config,
      input: input,
      options: options,
    );
  }

  List<String> getAllInputs(PigeonBuildConfig config) {
    var resolvedInputs = config.inputsInferred 
        ? getInferredInputs(config) 
        : config.inputs.map((input) => combinePath(input.input, config.mainInput?.input));
    return resolvedInputs
        .where((inputPath) => inputPath != null)
        .cast<String>()
        .toList();
  }
  
  List<String> getInferredInputs(PigeonBuildConfig config) {
    final mainInput = config.mainInput;
    if (mainInput == null) return [];

    var inputDirPath = mainInput.input;
    if (inputDirPath == null) return [];

    var inputDir = Directory(inputDirPath);
    if (!inputDir.existsSync()) return [];

    return inputDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => p.join(inputDir.path, p.relative(file.path, from: inputDir.path)))
        .toList();
  }

  String? combineOutFilePath({
    PigeonBuildOutputConfig? out,
    PigeonBuildOutputConfig? baseOut,
  }) {
    if (out == null) {
      return null;
    }

    return combinePath(out.path, baseOut?.path);
  }

  String? combinePath(String? path, String? basePath) {
    final String result;
    final isBase = path?.startsWith('/') ?? false;

    if (isBase) {
      path = path!.substring(1);
    }

    if (path == null) {
      return null;
    } else if (isBase || basePath == null) {
      result = path;
    } else {
      result = pathContext.join(basePath, path);
    }

    return pathContext.normalize(result);
  }

  String? combinePackage(String? package, String? basePackage) {
    if (package == null) {
      return basePackage;
    }

    if (package.startsWith('.') && basePackage != null) {
      return basePackage + package;
    }

    return package;
  }

  bool _shouldInfer(PigeonBuildOutputConfig? outConfigFromMainInput, PigeonBuildConfig config) {
    return config.inputsInferred && outConfigFromMainInput != null;
  }

  String _snakeToPascal(String str) {
    var namePartsJoined = str
        .split(RegExp(r"_+"))
        .map((namePart) {
          if (namePart.isEmpty) return "";
          return namePart[0].toUpperCase() + namePart.substring(1);
        })
        .join();

    var strOnlyUnderscores = namePartsJoined.isEmpty;
    return strOnlyUnderscores ? str : namePartsJoined;
  }

  String _pascalToSnake(String str) {
    return str.replaceAllMapped(
      RegExp(r"_*[A-Z]+"),
      (match) {
        var namePart = match[0]!.replaceAll("_", "");
        return "_${namePart.toLowerCase()}";
      },
    );
  }
}
