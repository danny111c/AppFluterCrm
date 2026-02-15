import 'package:flutter/material.dart';

class ReusableDataTablePanel extends StatefulWidget {
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
  final Widget? filterActions;

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
    this.filterActions,
  });

  @override
  State<ReusableDataTablePanel> createState() => _ReusableDataTablePanelState();
}

class _ReusableDataTablePanelState extends State<ReusableDataTablePanel> {
  final ScrollController _verticalController = ScrollController();

  String _getColumnName(DataColumn column) {
    if (column.label is Text) {
      return (column.label as Text).data!;
    }
    return 'Acciones';
  }

 @override
  Widget build(BuildContext context) {
    const borderColor = Color.fromARGB(255, 35, 35, 35);
    const borderWidth = 0.5;
    const headerAndSearchColor = Color.fromARGB(255, 17, 17, 18);

  // --- LÓGICA PARA RECUPERAR LA BARRA DE BÚSQUEDA AUTOMÁTICAMENTE ---
    Widget? headerContent = widget.filterActions;

    // Si no hay acciones de filtro pero sí hay un controlador de búsqueda,
    // creamos la barra de búsqueda por defecto con el nuevo diseño.
    if (headerContent == null && widget.searchController != null) {
      headerContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BUSCADOR RÁPIDO", 
            style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: TextField(
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              onSubmitted: widget.onSearchSubmitted,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                hintText: 'Buscar...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.black,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Color(0xFF232323))
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: const BorderSide(color: Colors.amber, width: 0.5)
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // --- BLOQUE 1: SOLO SE MUESTRA SI HAY CONTENIDO (FILTROS O BUSCADOR) ---
        if (headerContent != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: headerAndSearchColor,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: headerContent,
          ),

        // --- ESPACIO DE SEPARACIÓN (Solo si hay cabecera) ---
        if (headerContent != null) const SizedBox(height: 15),

        // --- BLOQUE 2: TABLA CON SU PROPIO BORDE ---
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: Table(
                                defaultColumnWidth: const IntrinsicColumnWidth(),
                                children: [
                                  TableRow(
                                    decoration: const BoxDecoration(
                                      color: headerAndSearchColor,
                                      border: Border(bottom: BorderSide(color: borderColor, width: borderWidth)),
                                    ),
                                    children: widget.columns.map((column) {
                                      return Container(
                                        height: 55.0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                        alignment: Alignment.centerLeft,
                                        child: DefaultTextStyle(
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                          child: column.label,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  ..._buildRows(borderColor, borderWidth),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Divider(color: borderColor, height: borderWidth, thickness: borderWidth),
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPageButton(Icons.first_page, widget.currentPage > 1, 1),
                      _buildPageButton(Icons.chevron_left, widget.currentPage > 1, widget.currentPage - 1),
                      const SizedBox(width: 15),
                      Text(
                        'Página ${widget.currentPage} de ${widget.totalPages}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 15),
                      _buildPageButton(Icons.chevron_right, widget.currentPage < widget.totalPages, widget.currentPage + 1),
                      _buildPageButton(Icons.last_page, widget.currentPage < widget.totalPages, widget.totalPages),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<TableRow> _buildRows(Color borderColor, double borderWidth) {
    if (widget.isLoading && widget.data.isEmpty) {
      return _generateSkeletonRows(borderColor, borderWidth);
    }
    return List.generate(widget.data.length, (index) {
      final item = widget.data[index];
      final bool showBorder = index != widget.data.length - 1;
      return TableRow(
        decoration: BoxDecoration(
          border: showBorder ? Border(bottom: BorderSide(color: borderColor, width: borderWidth)) : null,
        ),
        children: widget.columns.map((column) {
          final columnName = _getColumnName(column);
          final cellData = item[columnName];
          return Container(
            constraints: const BoxConstraints(minHeight: 45.0, maxHeight: 55.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            alignment: Alignment.centerLeft,
            child: widget.cellBuilder != null
                ? widget.cellBuilder!(cellData, columnName)
                : cellData is Widget
                    ? cellData
                    : Text(
                        cellData.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
          );
        }).toList(),
      );
    });
  }

  List<TableRow> _generateSkeletonRows(Color borderColor, double borderWidth) {
    return List.generate(10, (index) {
      return TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: borderWidth)),
        ),
        children: widget.columns.map((column) {
          return Container(
            constraints: const BoxConstraints(minHeight: 45.0, maxHeight: 55.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            alignment: Alignment.centerLeft,
            child: Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: const Color.fromARGB(55, 61, 61, 61).withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildPageButton(IconData icon, bool enabled, int page) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: enabled ? () => widget.onPageChanged?.call(page) : null,
      color: enabled ? Colors.white : Colors.grey.withOpacity(0.3),
    );
  }
}