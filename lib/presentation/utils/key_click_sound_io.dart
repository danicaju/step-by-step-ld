import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

typedef _GetProcessHeapNative = Pointer<Void> Function();
typedef _GetProcessHeapDart = Pointer<Void> Function();
typedef _HeapAllocNative = Pointer<Uint8> Function(
  Pointer<Void> hHeap,
  Uint32 dwFlags,
  IntPtr dwBytes,
);
typedef _HeapAllocDart = Pointer<Uint8> Function(
  Pointer<Void> hHeap,
  int dwFlags,
  int dwBytes,
);
typedef _PlaySoundNative = Int32 Function(
  Pointer<Void> pszSound,
  Pointer<Void> hmod,
  Uint32 fdwSound,
);
typedef _PlaySoundDart = int Function(
  Pointer<Void> pszSound,
  Pointer<Void> hmod,
  int fdwSound,
);

const int _sndAsync = 0x0001;
const int _sndNodefault = 0x0002;
const int _sndMemory = 0x0004;

_PlaySoundDart? _winPlaySound;
Pointer<Void>? _controlPtr;
Pointer<Void>? _standardPtr;
bool _winInitTried = false;

bool isRunningInTest() => Platform.environment.containsKey('FLUTTER_TEST');

void initClickBuffers(Uint8List controlWav, Uint8List standardWav) {
  if (!Platform.isWindows || _winInitTried) return;
  _winInitTried = true;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final winmm = DynamicLibrary.open('winmm.dll');

    final getProcessHeap = kernel32
        .lookupFunction<_GetProcessHeapNative, _GetProcessHeapDart>(
          'GetProcessHeap',
        );
    final heapAlloc = kernel32.lookupFunction<_HeapAllocNative, _HeapAllocDart>(
      'HeapAlloc',
    );
    _winPlaySound = winmm.lookupFunction<_PlaySoundNative, _PlaySoundDart>(
      'PlaySoundW',
    );

    final heap = getProcessHeap();
    if (heap.address == 0) return;

    _controlPtr = _pinToHeap(heap, heapAlloc, controlWav);
    _standardPtr = _pinToHeap(heap, heapAlloc, standardWav);
  } catch (_) {
    _winPlaySound = null;
    _controlPtr = null;
    _standardPtr = null;
  }
}

Pointer<Void>? _pinToHeap(
  Pointer<Void> heap,
  _HeapAllocDart heapAlloc,
  Uint8List bytes,
) {
  final ptr = heapAlloc(heap, 0, bytes.length);
  if (ptr.address == 0) return null;
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  return ptr.cast<Void>();
}

void playMemClick(bool isControl, Uint8List wavBytes) {
  if (Platform.isWindows) {
    final playFn = _winPlaySound;
    final ptr = isControl ? _controlPtr : _standardPtr;
    if (playFn != null && ptr != null && ptr.address != 0) {
      playFn(ptr, nullptr, _sndMemory | _sndAsync | _sndNodefault);
      return;
    }
  }
  SystemSound.play(SystemSoundType.click);
}
