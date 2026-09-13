import 'package:flutter/material.dart';

import 'package:crusader_dashboard/util/test_utils.dart';

class CustomLoadingIndicator extends CircularProgressIndicator {
  CustomLoadingIndicator({super.key}) : super(value: (isUnitTest ? 0 : null));
}
