import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/sheet/adaptive_content_sheet.dart';

// ignore: must_be_immutable
class CustomSearchableDropDown extends StatefulWidget {
  List items = [];
  List? initialValue;
  double? searchBarHeight;
  Color? primaryColor;
  Color? backgroundColor;
  Color? dropdownBackgroundColor;
  EdgeInsetsGeometry? padding;
  EdgeInsetsGeometry? menuPadding;
  String? label;
  String? dropdownHintText;
  TextStyle? labelStyle;
  TextStyle? dropdownItemStyle;
  String? hint = '';
  String? multiSelectTag;
  int? initialIndex;
  Widget? prefixIcon;
  Widget? suffixIcon;
  bool? hideSearch;
  bool? enabled;
  bool? showClearButton;
  bool? menuMode;
  double? menuHeight;
  bool? multiSelect;
  bool? multiSelectValuesAsWidget;
  bool? showLabelInMenu;
  String? itemOnDialogueBox;
  Decoration? decoration;
  List dropDownMenuItems = [];
  final TextAlign? labelAlign;
  final ValueChanged onChanged;

  CustomSearchableDropDown({
    super.key,
    required this.items,
    this.label,
    required this.onChanged,
    this.hint,
    this.initialValue,
    this.labelAlign,
    this.searchBarHeight,
    this.primaryColor,
    this.padding,
    this.menuPadding,
    this.labelStyle,
    this.enabled,
    this.showClearButton,
    this.itemOnDialogueBox,
    required this.dropDownMenuItems,
    this.prefixIcon,
    this.suffixIcon,
    this.menuMode,
    this.menuHeight,
    this.initialIndex,
    this.multiSelect,
    this.multiSelectTag,
    this.multiSelectValuesAsWidget,
    this.hideSearch,
    this.decoration,
    this.showLabelInMenu,
    this.dropdownItemStyle,
    this.backgroundColor,
    this.dropdownBackgroundColor,
    this.dropdownHintText,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CustomSearchableDropDownState createState() =>
      _CustomSearchableDropDownState();
}

class _CustomSearchableDropDownState extends State<CustomSearchableDropDown>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String onSelectLabel = '';
  final searchC = TextEditingController();
  List menuData = [];
  List mainDataListGroup = [];
  List newDataList = [];

  List selectedValues = [];

  late AnimationController _menuController;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _menuController = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
        animationBehavior: AnimationBehavior.normal);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = widget.primaryColor ?? scheme.primary;
    final selectedChipColor = widget.primaryColor ?? scheme.primaryContainer;
    final selectedChipTextColor = AppTheme.foregroundFor(selectedChipColor);

    if (widget.initialIndex != null && widget.dropDownMenuItems.isNotEmpty) {
      onSelectLabel = widget.dropDownMenuItems[widget.initialIndex!].toString();
    }

    if (widget.multiSelect ?? false) {
      if (selectedValues.isEmpty) {
        if (widget.initialValue != null && widget.items.isNotEmpty) {
          if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
            selectedValues.clear();
          }

          for (int i = 0; i < widget.items.length; i++) {
            for (int j = 0; j < widget.initialValue!.length; j++) {
              if (widget.initialValue != null &&
                  widget.initialValue!.isNotEmpty) {
                if (widget.initialValue![j]['value'] ==
                    widget.items[i][widget.initialValue![j]['parameter']]) {
                  selectedValues.add('${widget.dropDownMenuItems[i]}-_-$i');
                  setState(() {});
                }
              }
            }
          }
        }
      }
    } else {
      if (onSelectLabel == '') {
        if (widget.initialValue != null && widget.items.isNotEmpty) {
          for (int i = 0; i < widget.items.length; i++) {
            if (widget.initialValue != null &&
                widget.initialValue!.isNotEmpty) {
              if (widget.initialValue![0]['value'] ==
                  widget.items[i][widget.initialValue![0]['parameter']]) {
                onSelectLabel = widget.dropDownMenuItems[i].toString();
                setState(() {});
              }
            }
          }
        }
      }
    }

    if (widget.items.isEmpty) {
      onSelectLabel = '';
      selectedValues.clear();
      widget.onChanged(null);
      setState(() {});
    }
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: widget.decoration,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  backgroundColor: widget.backgroundColor,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Padding(
                  padding: widget.padding ?? const EdgeInsets.all(1.0),
                  child: Row(
                    children: [
                      widget.prefixIcon ?? Container(),
                      ((widget.multiSelect == true &&
                                  widget.multiSelect != null) &&
                              selectedValues.isNotEmpty)
                          ? Expanded(
                              child: (widget.multiSelectValuesAsWidget ==
                                          true &&
                                      widget.multiSelectValuesAsWidget != null)
                                  ? Wrap(
                                      children: List.generate(
                                        selectedValues.length,
                                        (index) {
                                          return Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                5, 3, 5, 3),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: selectedChipColor,
                                                  borderRadius:
                                                      const BorderRadius.all(
                                                    Radius.circular(5.0),
                                                  )),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        5, 2, 5, 2),
                                                child: Text(
                                                  selectedValues[index]
                                                      .split('-_-')[0]
                                                      .toString(),
                                                  style: (widget.labelStyle ??
                                                          const TextStyle(
                                                              fontSize: 12))
                                                      .copyWith(
                                                    color:
                                                        selectedChipTextColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Text(
                                      selectedValues.length == 1
                                          ? widget.multiSelectTag == null
                                              ? '${selectedValues.length} values selected'
                                              : '${selectedValues.length} ${widget.multiSelectTag!} selected'
                                          : widget.multiSelectTag == null
                                              ? '${selectedValues.length} values selected'
                                              : '${selectedValues.length} ${widget.multiSelectTag!} selected',
                                      style: widget.labelStyle ??
                                          TextStyle(color: c.textSecondary),
                                    ))
                          : Expanded(
                              child: Text(
                              onSelectLabel == ''
                                  ? widget.label == null
                                      ? 'Select Value'
                                      : widget.label!
                                  : onSelectLabel,
                              textAlign: widget.labelAlign ?? TextAlign.start,
                              style: widget.labelStyle != null
                                  ? widget.labelStyle!.copyWith(
                                      color: onSelectLabel == ''
                                          ? c.textSecondary
                                          : null,
                                    )
                                  : TextStyle(
                                      color: onSelectLabel == ''
                                          ? c.textSecondary
                                          : c.textPrimary,
                                    ),
                            )),
                      Visibility(
                          visible: (widget.showClearButton != null &&
                              widget.showClearButton == true),
                          child: TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: primaryColor),
                            child: const Icon(
                              Icons.clear,
                            ),
                            onPressed: () {
                              widget.onChanged(null);
                              onSelectLabel = '';
                              setState(() {});
                            },
                          )),
                      widget.suffixIcon ??
                          Icon(
                            Icons.arrow_drop_down,
                            color: primaryColor,
                          )
                    ],
                  ),
                ),
                onPressed: () {
                  if (widget.enabled == null || widget.enabled == true) {
                    menuData.clear();
                    if (widget.items.isNotEmpty) {
                      for (int i = 0;
                          i < widget.dropDownMenuItems.length;
                          i++) {
                        menuData.add('${widget.dropDownMenuItems[i]}-_-$i');
                      }
                      mainDataListGroup = menuData;
                      newDataList = mainDataListGroup;
                      searchC.clear();
                      if (widget.menuMode != null && widget.menuMode == true) {
                        if (_menuController.value != 1) {
                          _menuController.forward();
                        } else {
                          _menuController.reverse();
                        }
                      } else {
                        showDialogBox(context);
                      }
                    }
                  }
                  setState(() {});
                },
              ),
            ),
            SizeTransition(
              sizeFactor: _menuController,
              child: searchBox(setState),
            )
          ],
        ),
        Visibility(visible: (widget.menuMode ?? false), child: _shoeMenuMode()),
      ],
    );
  }

  Widget _shoeMenuMode() {
    return SizeTransition(
      sizeFactor: _menuController,
      child: mainScreen(setState),
    );
  }

  Future<void> showDialogBox(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: AdaptiveContentSheet(
            title: widget.label ?? widget.hint ?? '',
            maxHeightFactor: 0.9,
            child: Padding(
              padding: widget.menuPadding ?? const EdgeInsets.all(15),
              child: StatefulBuilder(builder: (context, setState) {
                return Material(
                  color: Colors.transparent,
                  child: mainScreen(setState),
                );
              }),
            ),
          ),
        );
      },
    ).then((valueFromDialog) {
      // use the value as you wish
      setState(() {});
    });
  }

  Padding mainScreen(StateSetter setState) {
    final c = AppColors.of(context);
    final primaryColor =
        widget.primaryColor ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: widget.menuPadding ?? const EdgeInsets.all(0),
      child: Container(
        color: widget.backgroundColor,
        foregroundDecoration: BoxDecoration(
          border: Border(
            top: BorderSide.none,
            right: BorderSide(color: c.cardBorder),
            left: BorderSide(color: c.cardBorder),
            bottom: BorderSide(color: c.cardBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Visibility(
                visible:
                    ((widget.showLabelInMenu ?? false) && widget.label != null),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.label.toString(),
                    style: widget.labelStyle != null
                        ? widget.labelStyle!.copyWith(
                            color: primaryColor,
                          )
                        : TextStyle(
                            color: primaryColor,
                          ),
                  ),
                )),
            Visibility(
                visible: widget.multiSelect ?? false,
                child: Row(
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                        'Select All',
                        style: widget.labelStyle != null
                            ? widget.labelStyle!.copyWith(
                                color: primaryColor,
                              )
                            : TextStyle(
                                color: primaryColor,
                              ),
                      ),
                      onPressed: () {
                        selectedValues.clear();
                        for (int i = 0; i < newDataList.length; i++) {
                          selectedValues.add(newDataList[i]);
                        }
                        setState(() {});
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text(
                        'Clear All',
                        style: widget.labelStyle != null
                            ? widget.labelStyle!.copyWith(
                                color: primaryColor,
                              )
                            : TextStyle(
                                color: primaryColor,
                              ),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedValues.clear();
                        });
                      },
                    ),
                  ],
                )),
            Visibility(
              visible: !(widget.menuMode ?? false),
              child: searchBox(setState),
            ),
            (widget.menuMode ?? false)
                ? SizedBox(
                    height: widget.menuHeight ?? 150,
                    child: mainList(setState),
                  )
                : Expanded(
                    child: mainList(setState),
                  ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(
                    'Close',
                    style: widget.labelStyle != null
                        ? widget.labelStyle!.copyWith(
                            color: primaryColor,
                          )
                        : TextStyle(
                            color: primaryColor,
                          ),
                  ),
                  onPressed: () {
                    if (widget.menuMode ?? false) {
                      _menuController.reverse();
                    } else {
                      Navigator.pop(context);
                    }
                    setState(() {});
                  },
                ),
                Visibility(
                  visible: (widget.multiSelect ?? false),
                  child: TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(
                      'Done',
                      style: widget.labelStyle != null
                          ? widget.labelStyle!.copyWith(
                              color: primaryColor,
                            )
                          : TextStyle(
                              color: primaryColor,
                            ),
                    ),
                    onPressed: () {
                      var sendList = [];
                      for (int i = 0; i < menuData.length; i++) {
                        if (selectedValues.contains(menuData[i])) {
                          sendList.add(widget.items[i]);
                        }
                      }
                      widget.onChanged(jsonEncode(sendList));
                      if (widget.menuMode ?? false) {
                        _menuController.reverse();
                      } else {
                        Navigator.pop(context);
                      }
                      setState(() {});
                    },
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Visibility searchBox(StateSetter setState) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = widget.primaryColor ?? scheme.primary;
    final searchBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: c.cardBorder, width: 1),
    );

    return Visibility(
      visible: widget.hideSearch == null ? true : !widget.hideSearch!,
      child: SizedBox(
        height: widget.searchBarHeight,
        child: Padding(
          padding: EdgeInsets.all((widget.menuMode ?? false) ? 0.0 : 8.0),
          child: TextField(
            controller: searchC,
            style: TextStyle(color: c.textPrimary, fontFamily: 'Kanit'),
            decoration: InputDecoration(
              fillColor: widget.dropdownBackgroundColor ?? c.surface,
              filled: true,
              border: searchBorder,
              enabledBorder: searchBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: primaryColor, width: 1.6),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide:
                    BorderSide(color: c.cardBorder.withValues(alpha: 0.55)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              suffixIcon: Icon(
                Icons.search,
                color: primaryColor,
              ),
              contentPadding: const EdgeInsets.all(8),
              hintText: widget.dropdownHintText ?? 'Search Here...',
              hintStyle: TextStyle(color: c.textHint, fontFamily: 'Kanit'),
              isDense: true,
            ),
            onChanged: (v) {
              onItemChanged(v);
              setState(() {});
            },
          ),
        ),
      ),
    );
  }

  Scrollbar mainList(StateSetter setState) {
    final c = AppColors.of(context);
    final primaryColor =
        widget.primaryColor ?? Theme.of(context).colorScheme.primary;

    return Scrollbar(
      child: Container(
        color: widget.dropdownBackgroundColor ?? c.cardWhite,
        child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: newDataList.length,
            itemBuilder: (BuildContext context, int index) {
              return TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                    padding: const EdgeInsets.all(8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: Row(
                    children: [
                      Visibility(
                        visible: widget.multiSelect ?? false,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              0,
                              8,
                              0,
                            ),
                            child: Checkbox(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                value:
                                    selectedValues.contains(newDataList[index])
                                        ? true
                                        : false,
                                activeColor: primaryColor,
                                onChanged: (newValue) {
                                  if (selectedValues
                                      .contains(newDataList[index])) {
                                    setState(() {
                                      selectedValues.remove(newDataList[index]);
                                    });
                                  } else {
                                    setState(() {
                                      selectedValues.add(newDataList[index]);
                                    });
                                  }
                                }),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          newDataList[index].split('-_-')[0].toString(),
                          style: widget.dropdownItemStyle ??
                              TextStyle(
                                color: c.textPrimary,
                                fontFamily: 'Kanit',
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                onPressed: () {
                  if (widget.multiSelect ?? false) {
                    if (selectedValues.contains(newDataList[index])) {
                      setState(() {
                        selectedValues.remove(newDataList[index]);
                      });
                    } else {
                      setState(() {
                        selectedValues.add(newDataList[index]);
                      });
                    }
                  } else {
                    for (int i = 0; i < menuData.length; i++) {
                      if (menuData[i] == newDataList[index]) {
                        onSelectLabel = menuData[i].split('-_-')[0].toString();
                        widget.onChanged(widget.items[i]);
                      }
                    }
                    if (widget.menuMode ?? false) {
                      _menuController.reverse();
                    } else {
                      Navigator.pop(context);
                    }
                  }
                  setState(() {});
                },
              );
            }),
      ),
    );
  }

  void onItemChanged(String value) {
    setState(() {
      newDataList = mainDataListGroup
          .where((string) => string.toLowerCase().contains(value.toLowerCase()))
          .toList();
    });
  }
}
