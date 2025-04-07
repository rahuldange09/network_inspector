import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/base/data_wrapper.dart';
import '../../common/extensions/unix_extension.dart';
import '../../common/extensions/url_extension.dart';
import '../../common/utils/byte_util.dart';
import '../../common/utils/date_time_util.dart';
import '../../common/widgets/bottom_sheet.dart';
import '../../const/network_inspector_value.dart';
import '../../domain/entities/http_activity.dart';
import '../controllers/activity_provider.dart';
import '../widgets/container_label.dart';
import '../widgets/filter_bottom_sheet_content.dart';

/// A page that show list of logged HTTP Activities, for navigating to this
/// page use regular Navigator.push
/// ```dart
///  Navigator.push(
///   context,
///   MaterialPageRoute<void>(
///     builder: (context) => ActivityPage(),
///   ),
/// );
/// ```
class ActivityPage extends StatefulWidget {
  static const String routeName = '/http-activity';

  const ActivityPage({Key? key}) : super(key: key);

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  final _byteUtil = ByteUtil();

  final _dateTimeUtil = DateTimeUtil();
  final TextEditingController _searchTEC = TextEditingController();
  List<HttpActivity> _allHTTPActivities = [];
  late List<int?> _selectedStatusCodes = [];
  BuildContext? _buildContext;

  @override
  void initState() {
    super.initState();
    _searchTEC.addListener(_filterAPILogs);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ActivityProvider>(
      create: (context) => ActivityProvider(
        context: context,
      ),
      builder: (providerContext, __) {
        _buildContext = providerContext;
        return Scaffold(
          appBar: AppBar(
            title: const Text('API Logs'),
            actions: [
              IconButton(
                onPressed: () {
                  onTapFilterIcon(providerContext);
                },
                icon: Consumer<ActivityProvider>(
                  builder: (_, provider, child) {
                    return Icon(
                      Icons.filter_list_alt,
                      color: _selectedStatusCodes.isEmpty
                          ? Colors.white
                          : Colors.redAccent,
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: () => showClearAPILogDialog(onClear: () {
                  final provider = providerContext.read<ActivityProvider>();
                  provider.deleteActivities();
                  Navigator.of(context).pop();
                }),
                icon: const Icon(
                  Icons.delete,
                ),
              ),
            ],
          ),
          body: buildBody(),
        );
      },
    );
  }

  Widget buildBody() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Consumer<ActivityProvider>(
        builder: (_, provider, child) {
          final result = provider.fetchedActivity;
          switch (provider.fetchedActivity.status) {
            case Status.loading:
              return loadingWidget();
            case Status.success:
              _allHTTPActivities = result.data ?? [];

              return successBody();
            case Status.error:
              return errorMessage(result.message);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget successBody() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8).copyWith(bottom: 12),
          child: SizedBox(
            height: 48,
            child: SearchBar(
              controller: _searchTEC,
              backgroundColor: MaterialStateProperty.all(
                Colors.white10,
              ),
              trailing: [
                if (_searchTEC.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchTEC.clear();
                    },
                    icon: const Icon(Icons.clear),
                  )
              ],
            ),
          ),
        ),
        Expanded(
          child: Visibility(
            visible: _allHTTPActivities.isNotEmpty,
            replacement: emptyBody(),
            child: activityList(),
          ),
        ),
      ],
    );
  }

  Widget emptyBody() {
    return Center(
      child: Text(
        'There is no log, try to fetch something !',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget errorMessage(error) {
    return Center(
      child: Text(
        'Log has error $error',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget loadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget idleWidget(BuildContext context) {
    return Center(
      child: Text(
        'Please wait',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget activityList() {
    return ListView.separated(
      itemCount: _allHTTPActivities.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) =>
          activityTile(_allHTTPActivities[index], index, context),
    );
  }

  Widget activityTile(
    HttpActivity activity,
    int index,
    BuildContext context,
  ) {
    return ListTile(
      onTap: () {
        var provider = context.read<ActivityProvider>();
        provider.goToDetailActivity(activity);
      },
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${activity.request?.method} '
              '${activity.request?.path ?? '-'}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          ContainerLabel(
            text: '${activity.response?.responseStatusCode ?? 'N/A'}',
            color: NetworkInspectorValue.containerColor(
              activity.response?.responseStatusCode ?? 0,
            ),
            textColor: Colors.white,
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Visibility(
                visible: activity.request?.baseUrl?.isSecure ?? false,
                replacement: const Icon(
                  Icons.lock_open,
                  size: 18,
                  color: Colors.grey,
                ),
                child: const Icon(
                  Icons.lock,
                  size: 18,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 1,
                child: Text(
                  activity.request?.baseUrl ?? '-',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                activity.request?.createdAt?.convertToYmdHms ?? '-',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _byteUtil.totalTransferSize(
                  activity.request?.requestSize,
                  activity.response?.responseSize,
                  false,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _dateTimeUtil.milliSecondDifference(
                  activity.request?.createdAt,
                  activity.response?.createdAt,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _filterAPILogs() {
    final provider = _buildContext?.read<ActivityProvider>();
    provider?.search(_searchTEC.text.trim(), _selectedStatusCodes);
  }

  void onTapFilterIcon(BuildContext context) {
    final provider = context.read<ActivityProvider>();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return BottomSheetTemplate(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: FilterBottomSheetContent(
              responseStatusCodes: provider.statusCodes,
              onTapApplyFilter: (list) {
                Navigator.pop(context);
                provider.filterHttpActivities(list);
                _selectedStatusCodes = list;
              },
              provider: provider.filterProvider!,
            ),
          ),
        );
      },
    );
  }

  void showClearAPILogDialog({required VoidCallback onClear}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Clear API logs?"),
        content: const Text("Do you want to clear all API logs?"),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text(
              "CANCEL",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
              onPressed: onClear,
              child: const Text(
                "CLEAR",
                style: TextStyle(color: Colors.white),
              )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchTEC.dispose();
    super.dispose();
  }
}
