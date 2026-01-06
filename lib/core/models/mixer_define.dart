class MixerDefine {
  final String name;
  final int? index;
  final List<MixerDefine> children;
  int itemValue;
  int itemType;

  MixerDefine({
    required this.name,
    this.index,
    this.children = const [],
    this.itemValue = 0,
    this.itemType = 0,
  });

  @override
  String toString() {
    return 'MixerDefine(name: $name, index: $index, value: $itemValue, type: $itemType, children: ${children.length})';
  }
  
  void debugPrintTree([String prefix = '']) {
    // Determine the display string for the current node
    String display = name;
    if (index != null) {
      display += ' ($index)';
    }
    //display += ' [V:$itemValue, T:$itemType]';
    
    print('$prefix$display');
    
    // Recursively print children
    for (var child in children) {
      child.debugPrintTree('$prefix  ');
    }
  }
}
