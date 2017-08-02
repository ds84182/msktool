import 'dart:async';
import 'dart:collection';

class AsyncNotification {
  Completer _completer;

  Future get wait => (_completer ??= new Completer()).future;

  void notify() {
    _completer?.complete();
    _completer = null;
  }
}

class StreamBuffer<T> {
  final _buffers = new Queue<List<T>>();
  final _notification = new AsyncNotification();
  StreamSubscription<List<T>> _sub;

  var _index = 0;
  bool _done = false;

  StreamBuffer(Stream<List<T>> stream) {
    _sub = stream.listen((list) {
      _buffers.add(list);
      _notification.notify();
    }, onDone: () {
      _done = true;
      _notification.notify();
    });
  }

  Future cancel() => _sub.cancel();

  FutureOr<T> get next {
    if (_buffers.isEmpty) {
      if (_done) return null;
      return _notification.wait.then((_) => next);
    }

    var buf = _buffers.first;
    var data = buf[_index++];

    if (_index >= buf.length) {
      _buffers.removeFirst();
      _index = 0;
    }

    return data;
  }

  bool get done => _buffers.isEmpty && _done;

  FutureOr<List<T>> take(int count) async {
    var out = <T>[];

    do {
      var oldlen = out.length;
      out.addAll(_buffers.first.skip(_index).take(count - out.length));
      _index += out.length - oldlen;

      if (_index >= _buffers.first.length) {
        _buffers.removeFirst();
        _index = 0;
        if (_buffers.isEmpty) await _notification.wait;
      }
    } while (out.length < count);

    out.length = count;
    return out;
  }
}
