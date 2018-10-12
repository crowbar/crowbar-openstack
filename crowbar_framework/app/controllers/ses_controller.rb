class SesController < BarclampController
  protected

  def initialize_service
    @service_object = SesService.new logger
  end
end
