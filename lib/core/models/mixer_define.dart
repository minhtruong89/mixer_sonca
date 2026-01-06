class MixerDefine {
  final String name;
  final int? index;
  final List<MixerDefine> children;

  MixerDefine({
    required this.name,
    this.index,
    this.children = const [],
  });

  @override
  String toString() {
    return 'MixerDefine(name: $name, index: $index, children: ${children.length})';
  }
  
  void debugPrintTree([String prefix = '']) {
    // Determine the display string for the current node
    String display = name;
    if (index != null) {
      display += ' ($index)';
    }
    
    print('$prefix$display');
    
    // Recursively print children
    for (var child in children) {
      child.debugPrintTree('$prefix  ');
    }
  }
}
