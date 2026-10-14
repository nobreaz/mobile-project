import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/input_text_field.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/theme/app_text_styles.dart';

/// Formulário de cadastro e edição de veículo.
/// Se [vehicle] for nulo, funciona como CADASTRO; caso contrário, EDIÇÃO.
class VehicleFormPage extends StatefulWidget {
  final VehicleModel? vehicle;

  const VehicleFormPage({super.key, this.vehicle});

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  late String plate;
  late String chassis;
  late String model;
  late String color;
  late String year;
  late String seats;
  late String mileage;
  late VehicleType type;
  late VehicleStatus status;

  bool get isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    plate = v?.plate ?? '';
    chassis = v?.chassis ?? '';
    model = v?.model ?? '';
    color = v?.color ?? '';
    year = v?.year.toString() ?? '';
    seats = v?.seats.toString() ?? '';
    mileage = v?.mileage.toString() ?? '';
    type = v?.type ?? VehicleType.passeio;
    status = v?.status ?? VehicleStatus.disponivel;
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_pad(d.day)}/${_pad(d.month)}';

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Confirma a devolução das reservas afetadas para Pendente.
  Future<bool> _confirmRelease(
    List<RequestModel> bookings, {
    required bool becomesUnavailable,
  }) async {
    final reason = becomesUnavailable
        ? 'Ao mudar o status para "${status.label}", o veículo deixa de '
              'atender estas reservas:'
        : 'Com menos lugares, o veículo deixa de comportar estas reservas:';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reservas afetadas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              for (final r in bookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event,
                        size: 16,
                        color: AppColors.iconMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '#${r.id} · ${r.destination} · '
                          '${_fmtDate(r.departure)} · '
                          '${r.passengers} passageiro(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                'Se continuar, elas voltam para "Pendente" e precisam ser '
                'realocadas em Solicitações Pendentes.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Continuar',
              style: TextStyle(color: AppColors.rejected),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _save() async {
    if (plate.trim().isEmpty || model.trim().isEmpty) {
      _showMessage('Preencha ao menos a placa e o modelo do veículo.');
      return;
    }

    final parsedYear = int.tryParse(year) ?? 0;
    final parsedSeats = int.tryParse(seats) ?? 0;
    final parsedMileage = int.tryParse(mileage) ?? 0;

    if (isEditing) {
      final vehicle = widget.vehicle!;
      final bookings = RequestController.instance.activeBookingsOf(vehicle.id);

      final becomesUnavailable =
          status == VehicleStatus.emManutencao ||
          status == VehicleStatus.inativo;

      // Carro em viagem: não pode ir para manutenção/inativo agora.
      final inUse = bookings
          .where((r) => r.status == RequestStatus.emUso)
          .toList();
      if (becomesUnavailable && inUse.isNotEmpty) {
        _showMessage(
          'O veículo está em uso. Registre a devolução (check-in) '
          'antes de mudar o status para "${status.label}".',
        );
        return;
      }

      // Reservas aprovadas que o veículo deixará de atender.
      final approved = bookings.where(
        (r) => r.status == RequestStatus.aprovada,
      );
      final toRelease = becomesUnavailable
          ? approved.toList()
          : approved.where((r) => r.passengers > parsedSeats).toList();

      if (toRelease.isNotEmpty) {
        final confirmed = await _confirmRelease(
          toRelease,
          becomesUnavailable: becomesUnavailable,
        );
        if (!confirmed || !mounted) return;

        RequestController.instance.releaseBookings(toRelease.map((r) => r.id));
      }

      VehicleController.instance.updateVehicle(
        vehicle.id,
        plate: plate.trim(),
        chassis: chassis.trim(),
        model: model.trim(),
        color: color.trim(),
        year: parsedYear,
        seats: parsedSeats,
        mileage: parsedMileage,
        type: type,
        status: status,
      );
      _showMessage(
        toRelease.isEmpty
            ? 'Veículo atualizado com sucesso!'
            : 'Veículo atualizado. ${toRelease.length} reserva(s) '
                  'voltaram para aprovação.',
      );
    } else {
      VehicleController.instance.addVehicle(
        plate: plate.trim(),
        chassis: chassis.trim(),
        model: model.trim(),
        color: color.trim(),
        year: parsedYear,
        seats: parsedSeats,
        mileage: parsedMileage,
        type: type,
        status: status,
      );
      _showMessage('Veículo cadastrado com sucesso!');
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Veículo' : 'Cadastrar Veículo',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            InputTextField(
              label: 'Placa',
              hint: 'AAA-0A00',
              inputText: plate,
              onChanged: (text) => plate = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Modelo',
              hint: 'Ex.: Toyota Corolla',
              inputText: model,
              onChanged: (text) => model = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Chassi',
              hint: 'Informe o número do chassi',
              inputText: chassis,
              onChanged: (text) => chassis = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Cor',
              hint: 'Ex.: Prata',
              inputText: color,
              onChanged: (text) => color = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Ano',
              type: InputFieldType.number,
              hint: 'Ex.: 2022',
              inputText: year,
              onChanged: (text) => year = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Quantidade de lugares',
              type: InputFieldType.number,
              hint: 'Ex.: 5',
              inputText: seats,
              onChanged: (text) => seats = text,
            ),
            const SizedBox(height: 16),
            InputTextField(
              label: 'Quilometragem',
              type: InputFieldType.number,
              hint: 'Ex.: 42500',
              inputText: mileage,
              onChanged: (text) => mileage = text,
            ),
            const SizedBox(height: 20),
            _dropdown<VehicleType>(
              label: 'Tipo / categoria',
              value: type,
              items: VehicleType.values,
              labelBuilder: (t) => t.label,
              onChanged: (v) => setState(() => type = v),
            ),
            const SizedBox(height: 20),
            _dropdown<VehicleStatus>(
              label: 'Status operacional',
              value: status,
              items: VehicleStatus.values,
              labelBuilder: (s) => s.label,
              onChanged: (v) => setState(() => status = v),
            ),
            const SizedBox(height: 40),
            AppButton(
              label: isEditing ? 'Salvar alterações' : 'Cadastrar',
              onPressed: _save,
            ),
            const SizedBox(height: 10),
            AppButton(
              variant: AppButtonVariant.cancel,
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Campo de seleção com o mesmo visual dos InputTextField.
  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(label, style: AppTextStyles.actionLabel),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            shadows: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        labelBuilder(item),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
