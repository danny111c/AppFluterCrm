import 'package:flutter/material.dart';

class ReusableDataTablePanel extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<DataColumn> columns;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final int currentPage;
  final int totalPages;
  final void Function(int)? onPageChanged;
  final Widget Function(dynamic data, String columnKey)? cellBuilder;
  final bool isLoading;

  const ReusableDataTablePanel({
    super.key,
    required this.data,
    required this.columns,
    this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageChanged,
    this.cellBuilder,
    this.isLoading = false,
  });

  String _getColumnName(DataColumn column) {
    if (column.label is Text) {
      return (column.label as Text).data!;
    }
    return 'Acciones';
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
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        } else if (columnName == 'Estado') {
          skeletonRow[columnName] = Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        } else {
          final widths = [80.0, 120.0, 100.0, 90.0, 110.0];
          skeletonRow[columnName] = Container(
            width: widths[index % widths.length],
            height: 16,
            decoration: BoxDecoration(
              color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }
      }
      return skeletonRow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 20, 20, 24),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color.fromARGB(99, 255, 255, 255), width: 0.5),
      ),
      child: Column(
        children: [
          // --- BARRA DE BÚSQUEDA (FIJA ARRIBA) ---
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
                ),
              ),
            ),
          ),

          // --- CUERPO DE LA TABLA (CON DOBLE SCROLL) ---
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Scrollbar( // Añadimos scrollbar para mejor UX
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical, // SCROLL VERTICAL
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal, // SCROLL HORIZONTAL
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          border: const TableBorder(horizontalInside: BorderSide(color: Color.fromARGB(99, 255, 255, 255), width: 0.5)),
                          headingRowColor: MaterialStateProperty.all(const Color.fromARGB(255, 40, 40, 45)), // Color un poco más suave
                          dataRowMinHeight: 45.0,
                          dataRowMaxHeight: 55.0,
                          columnSpacing: 24.0,
                          columns: columns,
                          rows: (isLoading && data.isEmpty ? _generateSkeletonRows() : data).map((item) {
                            return DataRow(
                              cells: columns.map((column) {
                                final columnName = _getColumnName(column);
                                final cellData = item[columnName];
                                
                                if (cellBuilder != null) {
                                  return DataCell(cellBuilder!(cellData, columnName));
                                }
                                
                                return DataCell(
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    child: cellData is Widget
                                      ? cellData
                                      : Text(
                                          cellData.toString(),
                                          style: const TextStyle(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  )
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // --- PAGINACIÓN (FIJA ABAJO) ---
          const Divider(color: Color.fromARGB(99, 255, 255, 255), height: 1),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageButton(Icons.first_page, currentPage > 1, 1),
                _buildPageButton(Icons.chevron_left, currentPage > 1, currentPage - 1),
                const SizedBox(width: 15),
                Text(
                  'Página $currentPage de $totalPages', 
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)
                ),
                const SizedBox(width: 15),
                _buildPageButton(Icons.chevron_right, currentPage < totalPages, currentPage + 1),
                _buildPageButton(Icons.last_page, currentPage < totalPages, totalPages),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para limpiar los botones de página
  Widget _buildPageButton(IconData icon, bool enabled, int page) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: enabled ? () => onPageChanged?.call(page) : null,
      color: enabled ? Colors.white : Colors.grey.withOpacity(0.3),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}