import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Gilroy-SemiBold',
            fontSize: 19,
          ),
        ),
        SizedBox(height: 4),
        Theme(
          data: Theme.of(context).copyWith(
            canvasColor: Theme.of(context).dialogBackgroundColor,
          ),
          child: Container(
            decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                    width: 1.5,
                  ),
                )),
            child: DropdownButton<String>(
              isDense: true,
              isExpanded: true,
              hint: Text(
                hint,
                style: TextStyle(
                  fontFamily: 'Gilroy-Medium',
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              value: value,
              items: items.isNotEmpty
                  ? items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontFamily: 'Gilroy-Medium'),
                  ),
                );
              }).toList()
                  : [
                DropdownMenuItem(
                  value: '',
                  enabled: false,
                  child: Center(
                    child: SizedBox(
                      width: 40,
                      height: 50,
                      child: LoadingAnimationWidget.waveDots(
                        color: Theme.of(context).colorScheme.secondary,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}