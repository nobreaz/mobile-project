import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:project/core/components/app_button_variant.dart';
import 'package:project/core/components/input_text_field.dart';
import 'package:project/core/controllers/request_controller.dart';
import 'package:project/core/theme/app_colors.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  String reasonTravel = '';
  String destination = '';
  int numberPassengers = 0;
  DateTime? departureDateTime;
  DateTime? returnDate;

  // Trocar a "versão" do formulário força os campos a se recriarem vazios.
  int _formVersion = 0;

  void _clearForm() {
    setState(() {
      reasonTravel = '';
      destination = '';
      numberPassengers = 0;
      departureDateTime = null;
      returnDate = null;
      _formVersion++;
    });
  }

  void _submit() {
    // Validações simples antes de enviar.
    if (reasonTravel.trim().isEmpty || destination.trim().isEmpty) {
      _showMessage('Preencha o motivo e o destino da viagem.');
      return;
    }
    if (departureDateTime == null || returnDate == null) {
      _showMessage('Selecione as datas de saída e de retorno.');
      return;
    }

    // Cria a solicitação (cai automaticamente em "Minhas Solicitações").
    RequestController.instance.addRequest(
      reason: reasonTravel.trim(),
      destination: destination.trim(),
      passengers: numberPassengers,
      departure: departureDateTime,
      returnDate: returnDate,
    );

    _showMessage('Solicitação enviada com sucesso!');
    Navigator.of(context).pushReplacementNamed('/my-requests');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nova Solicitação',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                        InputTextField(
                          label: 'Número de passageiros',
                          type: InputFieldType.number,
                          inputText: '',
                          hint: 'Informe a quantidade de passageiros',
                          onChanged: (text) =>
                              numberPassengers = int.tryParse(text) ?? 0,
                        ),
                        const SizedBox(height: 20),
                        InputTextField(
                          label: 'Data e hora de saída',
                          type: InputFieldType.dateTime,
                          inputText: '',
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
                          inputText: '',
                          hint: 'Selecione a data',
                          firstDate: departureDateTime ?? DateTime.now(),
                          onChanged: (_) {},
                          onDateSelected: (date) =>
                              setState(() => returnDate = date),
                        ),
                        const Spacer(),
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              AppButton(label: 'Confirmar', onPressed: _submit),
                              const SizedBox(height: 10),
                              AppButton(
                                variant: AppButtonVariant.cancel,
                                label: 'Limpar',
                                onPressed: _clearForm,
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<DateTime?>('departureDateTime', departureDateTime),
    );
  }
}
