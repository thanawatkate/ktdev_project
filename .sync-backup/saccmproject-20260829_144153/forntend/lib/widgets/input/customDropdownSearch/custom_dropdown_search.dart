import 'package:flutter/material.dart';
import 'package:saccm/constants/app_theme.dart';
import 'package:saccm/widgets/TemplateInput/template_input.dart';
import 'package:saccm/widgets/input/customDropdownSearch/dropdown_search/dropdown_search.dart';

// ignore: must_be_immutable
class CustomDropdownSearch extends StatelessWidget {
  final List data;
  final String title;
  final ValueChanged onChanged;
  // ignore: prefer_typing_uninitialized_variables

  const CustomDropdownSearch(
      {super.key,
      required this.data,
      this.title = "",
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return TemplateInput(
      title: title,
      child: CustomSearchableDropDown(
        dropdownHintText: 'Keyword Search Here... ',
        showLabelInMenu: true,
        // initialValue: const [
        //   {
        //     'parameter': 'name',
        //     'value': 'Amir',
        //   }
        // ],
        dropdownItemStyle: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Kanit',
        ),
        primaryColor: scheme.primary,
        backgroundColor: c.cardWhite,
        dropdownBackgroundColor: c.cardWhite,

        menuMode: true,
        labelStyle: TextStyle(
          color: c.textSecondary,
          fontFamily: 'Kanit',
          fontWeight: FontWeight.bold,
        ),
        items: data,
        prefixIcon: const Icon(Icons.search),
        dropDownMenuItems: data.map((item) {
          return item['name'];
        }).toList(),
        onChanged: onChanged,
        padding: const EdgeInsets.only(bottom: 12, top: 11),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide.none,
            right: BorderSide.none,
            left: BorderSide.none,
            bottom: BorderSide(width: 2.0, color: c.cardBorder),
          ),
        ),
      ),
    );
  }
}
