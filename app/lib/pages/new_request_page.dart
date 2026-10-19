import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/input_text_field.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/controllers/user_controller.dart';
import 'package:project/core/controllers/vehicle_controller.dart';
import 'package:project/core/models/request_model.dart';
import 'package:project/core/models/user_model.dart';
import 'package:project/core/models/vehicle_model.dart';
import 'package:project/core/theme/app_colors.dart';
import 'package:project/core/theme/app_text_styles.dart';

class NewRequestPage extends StatefulWidget {
  /// Quando informado, a tela funciona em modo de edição.
  final RequestModel? request;

  const NewRequestPage({super.key, this.request});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  String reasonTravel = '';
  String destination = '';
  int numberPassengers = 1; // o motorista conta como passageiro
  DateTime? departureDateTime;
  DateTime? returnDate;
  ReturnPeriod? returnPeriod;

  // Trocar a "versão" do formulário força os campos a se recriarem.
  int _formVersion = 0;

  bool get _isEditing => widget.request != null;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    if (r != null) {
      reasonTravel = r.reason;
      destination = r.destination;
      numberPassengers = r.passengers;
      departureDateTime = r.departure;
      returnDate = r.returnDate;
      returnPeriod = r.returnPeriod;
    }
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _fmtDate(DateTime? d) =>
      d == null ? '' : '${_pad(d.day)}/${_pad(d.month)}/${d.year}';

  String _fmtDateTime(DateTime? d) =>
      d == null ? '' : '${_fmtDate(d)} ${_pad(d.hour)}:${_pad(d.minute)}';

  /// Limite do seletor: a maior lotação entre os veículos ativos.
  int get _maxPassengers {
    final seats = VehicleController.instance.vehicles
        .where(
          (v) =>
              v.status != VehicleStatus.emManutencao &&
              v.status != VehicleStatus.inativo,
        )
        .map((v) => v.seats);
    if (seats.isEmpty) return 1;
    return seats.reduce((a, b) => a > b ? a : b);
  }

  void _clearForm() {
    setState(() {
      reasonTravel = '';
      destination = '';
      numberPassengers = 1;
      departureDateTime = null;
      returnDate = null;
      returnPeriod = null;
      _formVersion++;
    });
  }

  void _submit() {
    final user = UserController.instance.currentUser;

    // Regra 5.2.4: CNH vencida ou não cadastrada não pode solicitar.
    if (!user.canRequestVehicle) {
      _showMessage(
        'Sua CNH está vencida ou não cadastrada. '
        'Procure o setor Administrativo.',
      );
      return;
    }

    if (reasonTravel.trim().isEmpty || destination.trim().isEmpty) {
      _showMessage('Preencha o motivo e o destino da viagem.');
      return;
    }
    if (departureDateTime == null || returnDate == null) {
      _showMessage('Selecione as datas de saída e de retorno.');
      return;
    }
    if (returnPeriod == null) {
      _showMessage('Selecione o período de retorno (manhã ou tarde).');
      return;
    }

    // A CNH precisa estar válida até o fim da viagem.
    final expiry = user.cnhExpiry;
    if (expiry != null &&
        returnDate!.isAfter(DateTime(expiry.year, expiry.month, expiry.day))) {
      _showMessage(
        'Sua CNH vence em ${_fmtDate(expiry)}, antes da data de retorno.',
      );
      return;
    }

    final deadline = DateTime(
      returnDate!.year,
      returnDate!.month,
      returnDate!.day,
      returnPeriod!.endHour,
    );
    if (!deadline.isAfter(departureDateTime!)) {
      _showMessage(
        'O retorno precisa ser depois da saída. '
        'Verifique a data e o período de retorno.',
      );
      return;
    }

    // Regra 4.4: o usuário não pode ter duas reservas no mesmo horário.
    final hasConflict = RequestController.instance.userHasConflict(
      userId: user.id,
      start: departureDateTime!,
      end: deadline,
      ignoreRequestId: widget.request?.id,
    );
    if (hasConflict) {
      _showMessage(
        'Você já tem uma solicitação ativa nesse período. '
        'Escolha outro horário ou cancele a anterior.',
      );
      return;
    }

    if (_isEditing) {
      final reverted = RequestController.instance.updateRequest(
        widget.request!.id,
        reason: reasonTravel.trim(),
        destination: destination.trim(),
        passengers: numberPassengers,
        departure: departureDateTime!,
        returnDate: returnDate!,
        returnPeriod: returnPeriod!,
      );
      _showMessage(
        reverted
            ? 'Solicitação alterada. Ela voltou para aprovação.'
            : 'Solicitação atualizada.',
      );
      Navigator.of(context).pop();
      return;
    }

    RequestController.instance.addRequest(
      reason: reasonTravel.trim(),
      destination: destination.trim(),
      passengers: numberPassengers,
      departure: departureDateTime,
      returnDate: returnDate,
      returnPeriod: returnPeriod,
    );

    _showMessage('Solicitação enviada com sucesso!');
    Navigator.of(context).pushReplacementNamed('/my-requests');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final user = UserController.instance.currentUser;
    final isApprovedEdit =
        _isEditing && widget.request!.status == RequestStatus.aprovada;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Solicitação' : 'Nova Solicitação',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: KeyedSubtree(
                    key: ValueKey(_formVersion),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        if (!user.canRequestVehicle) ...[
                          _cnhBlockedWarning(user),
                          const SizedBox(height: 10),
                        ],
                        if (isApprovedEdit) ...[
                          _approvalWarning(),
                          const SizedBox(height: 10),
                        ],
                        InputTextField(
                          label: 'Motivo da viagem',
                          hint: 'Digite o motivo da viagem',
                          inputText: reasonTravel,
                          onChanged: (text) =>
                              setState(() => reasonTravel = text),
                        ),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Destino',
                          hint: 'Informe o destino / rota',
                          inputText: destination,
                          onChanged: (text) =>
                              setState(() => destination = text),
                        ),
                        const SizedBox(height: 20),
                        _passengerStepper(),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Data e hora de saída',
                          type: InputFieldType.dateTime,
                          inputText: _fmtDateTime(departureDateTime),
                          hint: 'Selecione a data e hora',
                          firstDate: DateTime.now(),
                          onChanged: (_) {},
                          onDateSelected: (date) =>
                              setState(() => departureDateTime = date),
                        ),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Data de retorno',
                          type: InputFieldType.date,
                          inputText: _fmtDate(returnDate),
                          hint: 'Selecione a data',
                          firstDate: departureDateTime ?? DateTime.now(),
                          onChanged: (_) {},
                          onDateSelected: (date) =>
                              setState(() => returnDate = date),
                        ),
                        const SizedBox(height: 20),
                        _periodSelector(),
                        const Spacer(),
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              AppButton(
                                label: _isEditing
                                    ? 'Salvar alterações'
                                    : 'Confirmar',
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                variant: AppButtonVariant.cancel,
                                label: _isEditing ? 'Cancelar' : 'Limpar',
                                onPressed: _isEditing
                                    ? () => Navigator.of(context).pop()
                                    : _clearForm,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Aviso exibido quando a CNH impede novas solicitações (regra 5.2.4).
  Widget _cnhBlockedWarning(UserModel user) {
    final message = user.cnhStatus == CnhStatus.vencida
        ? 'Sua CNH está vencida. Você não pode solicitar veículos até '
              'regularizar com o setor Administrativo.'
        : 'Sua CNH não está cadastrada. Procure o setor Administrativo.';

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.rejected.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.rejected),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso exibido ao editar uma solicitação já aprovada.
  Widget _approvalWarning() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canceled.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.canceled),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Esta solicitação já foi aprovada. Alterar datas, período ou '
              'passageiros fará ela voltar para aprovação e o veículo será '
              'liberado.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Seletor de passageiros: card com ícone, texto de apoio e
  /// botões circulares – / + com o número animado entre eles.
  Widget _passengerStepper() {
    final max = _maxPassengers;
    if (numberPassengers > max) numberPassengers = max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            'Número de passageiros',
            style: AppTextStyles.actionLabel,
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inclui o motorista',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Máximo de $max',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _stepButton(
                icon: Icons.remove,
                enabled: numberPassengers > 1,
                onTap: () => setState(() => numberPassengers--),
              ),
              SizedBox(
                width: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Text(
                    '$numberPassengers',
                    key: ValueKey(numberPassengers),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              _stepButton(
                icon: Icons.add,
                enabled: numberPassengers < max,
                onTap: () => setState(() => numberPassengers++),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? AppColors.primary : AppColors.iconMuted;

    return SizedBox(
      width: 34,
      height: 34,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          side: BorderSide(
            color: enabled ? color : color.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  /// Seletor de período de retorno (Manhã / Tarde).
  Widget _periodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text('Período de retorno', style: AppTextStyles.actionLabel),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: Row(
            children: [
              Expanded(
                child: _periodOption(
                  ReturnPeriod.manha,
                  Icons.wb_sunny_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _periodOption(ReturnPeriod.tarde, Icons.wb_twilight),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodOption(ReturnPeriod period, IconData icon) {
    final selected = returnPeriod == period;

    return GestureDetector(
      onTap: () => setState(() => returnPeriod = period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: ShapeDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
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
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : AppColors.primary),
            const SizedBox(height: 4),
            Text(
              period.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            Text(
              period.description,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white70 : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DateTime?>('departureDateTime', departureDateTime),
    );
  }
}
