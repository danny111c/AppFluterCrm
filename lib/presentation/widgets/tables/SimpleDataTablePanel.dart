import 'package:flutter/material.dart';
import 'package:proyectofinal/presentation/widgets/buttons/add_button.dart';

class SimpleDataTablePanel extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<DataColumn> columns;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;

  final bool isSmallScreen;
  final List<Widget> Function(int index)? rowActions;
  final int currentPage;
  final int totalPages;
  final void Function(int)? onPageChanged;
  final bool isLoading;

  const SimpleDataTablePanel({
    super.key,
    required this.data,
    required this.columns,
    this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.isSmallScreen = false,
    this.rowActions,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageChanged,
    this.isLoading = false,
  });

  String _getColumnName(DataColumn column) {
    if (column.label is Text) {
      return (column.label as Text).data!;
    }
    return column.label.toString();
  }

  List<Map<String, dynamic>> _generateSkeletonRows() {
    return List.generate(10, (index) {
      Map<String, dynamic> skeletonRow = {};
      for (var column in columns) {
        final columnName = _getColumnName(column);
        if (columnName == 'Acciones') {
          skeletonRow[columnName] = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSkeletonBox(24, 24),
              const SizedBox(width: 8),
              _buildSkeletonBox(24, 24),
            ],
          );
        } else if (columnName == 'Estado') {
          skeletonRow[columnName] = _buildSkeletonBox(60, 20, radius: 10);
        } else {
          skeletonRow[columnName] = _buildSkeletonBox(100, 16);
        }
      }
      return skeletonRow;
    });
  }

  Widget _buildSkeletonBox(double width, double height, {double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 20, 20, 24),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color.fromARGB(99, 255, 255, 255), width: 0.5),
      ),
      child: Column(
        children: [
          // 1. BARRA DE BÚSQUEDA
          if (searchController != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    hintText: 'Buscar y presionar Enter...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 30, 30, 34),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  ),
                ),
              ),
            ),

          // 2. ÁREA DE TABLA CON DOBLE SCROLL
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // SCROLL HORIZONTAL (Para columnas)
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ENCABEZADO FIJO
                        DataTable(
                          columnSpacing: 24,
                          headingRowHeight: 48,
                          dataRowMaxHeight: 0,
                          dataRowMinHeight: 0,
                          headingRowColor: WidgetStateProperty.all(const Color.fromARGB(255, 70, 70, 70)),
                          columns: columns.map((c) => DataColumn(label: c.label)).toList(),
                          rows: const [],
                        ),
                        // CONTENIDO DESPLAZABLE VERTICALMENTE
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical, // SCROLL VERTICAL (Para filas)
                            child: DataTable(
                              columnSpacing: 24,
                              headingRowHeight: 0, // Ocultar el header aquí
                              dataRowMaxHeight: isSmallScreen ? 50 : 60,
                              dataRowMinHeight: isSmallScreen ? 45 : 55,
                              dividerThickness: 0.5,
                              border: const TableBorder(horizontalInside: BorderSide(color: Color.fromARGB(99, 255, 255, 255), width: 0.5)),
                              columns: columns.map((c) => DataColumn(label: Container())).toList(),
                              rows: (isLoading ? _generateSkeletonRows() : data).asMap().entries.map((entry) {
                                final i = entry.key;
                                final item = entry.value;
                                return DataRow(
                                  cells: columns.map((column) {
                                    final columnName = _getColumnName(column);
                                    final cellValue = item[columnName];

                                    if (columnName == 'Acciones' && rowActions != null && !isLoading) {
                                      return DataCell(Row(mainAxisSize: MainAxisSize.min, children: rowActions!(i)));
                                    }

                                    return DataCell(
                                      cellValue is Widget 
                                        ? cellValue 
                                        : Text(cellValue?.toString() ?? '', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)
                                    );
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. PAGINACIÓN (FIJA ABAJO)
          const Divider(color: Color.fromARGB(99, 255, 255, 255), height: 1),
          Container(
            height: 56,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageIconButton(Icons.first_page, currentPage > 1, 1),
                _buildPageIconButton(Icons.chevron_left, currentPage > 1, currentPage - 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Página $currentPage de $totalPages',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                _buildPageIconButton(Icons.chevron_right, currentPage < totalPages, currentPage + 1),
                _buildPageIconButton(Icons.last_page, currentPage < totalPages, totalPages),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIconButton(IconData icon, bool enabled, int page) {
    return IconButton(
      icon: Icon(icon),
      onPressed: enabled ? () => onPageChanged?.call(page) : null,
      color: enabled ? Colors.white : Colors.grey.withOpacity(0.3),
    );
  }
}