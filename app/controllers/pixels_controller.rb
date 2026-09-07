class PixelsController < ApplicationController
  before_action :set_pixel, only: [:show, :edit, :update, :destroy]

  def index
    @pixels = policy_scope(Pixel).order(:name)
  end

  def show
    authorize @pixel
  end

  def new
    @pixel = current_account.pixels.new
    authorize @pixel
  end

  def create
    @pixel = current_account.pixels.new(pixel_params)
    authorize @pixel
    if @pixel.save
      redirect_to @pixel, notice: "Pixel created. Copy the snippet below into the landing page's <head>."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pixel
  end

  def update
    authorize @pixel
    if @pixel.update(pixel_params)
      redirect_to @pixel, notice: "Pixel updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @pixel
    @pixel.destroy
    redirect_to pixels_path, notice: "Pixel deleted."
  end

  private

  def set_pixel
    @pixel = current_account.pixels.find(params[:id])
  end

  def pixel_params
    landing_pages = params[:pixel][:allowed_landing_pages_text].to_s
      .split(/[\r\n,]+/).map(&:strip).reject(&:blank?)
    params.require(:pixel).permit(:name, :active).merge(allowed_landing_pages: landing_pages)
  end
end
