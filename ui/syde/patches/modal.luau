function syde:Modal(Modal)
	task.spawn(function()
		local ModalData = {
			Title = Modal.Title;
			Content = Modal.Content;
			ConfirmCallBack = Modal.ConfirmCallBack or Modal.ConfirmCallback or Modal.ConfimCallBack,
			CancelCallBack = Modal.CancelCallBack or Modal.CancelCallback,
		}

		local modalTemplate = window and sydeFindChild(window, "modal", "Modal")
		local ModalInstance = modalTemplate and modalTemplate:Clone()
		if not ModalInstance or not window then
			return
		end
		sydeSanitizeUiClone(ModalInstance)
		ModalInstance.Visible = true
		ModalInstance.Parent = window
		local modalParts = sydeResolveModal(ModalInstance)
		local dimOverlay = window and sydeFindChild(window, "dim", "Dim")
		if modalParts.Title then
			modalParts.Title.Text = ModalData.Title
			modalParts.Title.TextTransparency = 1
		end
		if modalParts.Content then
			modalParts.Content.Text = ModalData.Content
			modalParts.Content.TextTransparency = 1
		end
		ModalInstance.Size = UDim2.new(0, 350, 0, 144)
		ModalInstance.BackgroundTransparency = 1
		if modalParts.Confirm then
			modalParts.Confirm.BackgroundTransparency = 1
		end
		if modalParts.ConfirmLabel then
			modalParts.ConfirmLabel.TextTransparency = 1
		end
		if modalParts.Cancel then
			modalParts.Cancel.BackgroundTransparency = 1
		end
		if modalParts.CancelLabel then
			modalParts.CancelLabel.TextTransparency = 1
		end
		if modalParts.CancelStroke then
			modalParts.CancelStroke.Transparency = 1
		end

		local function openModal()
			if modalParts.Content then
				tweenservice:Create(
					modalParts.Content,
					TweenInfo.new(0.75, Enum.EasingStyle.Quint),
					{ Size = UDim2.new(1, modalParts.Content.Size.X.Offset, 1, modalParts.Content.TextBounds.Y) }
				):Play()
			end
			activeModals += 1
			local contentHeight = modalParts.Content and modalParts.Content.TextBounds.Y or 0
			tweenservice:Create(
				ModalInstance,
				TweenInfo.new(0.65, Enum.EasingStyle.Quint),
				{ Size = UDim2.new(0, 350, 0, contentHeight + 150) }
			):Play()
			tweenservice:Create(ModalInstance, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0 }):Play()
			if modalParts.UIStroke then
				tweenservice:Create(modalParts.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 0 }):Play()
			end
			if modalParts.Title then
				tweenservice:Create(modalParts.Title, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Content then
				tweenservice:Create(modalParts.Content, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Confirm then
				tweenservice:Create(modalParts.Confirm, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.5 }):Play()
			end
			if modalParts.ConfirmLabel then
				tweenservice:Create(modalParts.ConfirmLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.Cancel then
				tweenservice:Create(modalParts.Cancel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.CancelLabel then
				tweenservice:Create(modalParts.CancelLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			end
			if modalParts.CancelStroke then
				tweenservice:Create(modalParts.CancelStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 0 }):Play()
			end
		end
		openModal()

		local function closeModal()
			activeModals = math.max(activeModals - 1, 0)
			sydeSetInteractable(modalParts.Cancel, false)
			sydeSetInteractable(modalParts.Confirm, false)
			tweenservice:Create(ModalInstance, TweenInfo.new(0.75, Enum.EasingStyle.Quint), { Size = UDim2.new(0, 350, 0, 147) }):Play()
			tweenservice:Create(ModalInstance, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			if modalParts.Title then
				tweenservice:Create(modalParts.Title, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.UIStroke then
				tweenservice:Create(modalParts.UIStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
			end
			if modalParts.Content then
				tweenservice:Create(modalParts.Content, TweenInfo.new(0.3, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.Confirm then
				tweenservice:Create(modalParts.Confirm, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.ConfirmLabel then
				tweenservice:Create(modalParts.ConfirmLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.Cancel then
				tweenservice:Create(modalParts.Cancel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			end
			if modalParts.CancelLabel then
				tweenservice:Create(modalParts.CancelLabel, TweenInfo.new(1, Enum.EasingStyle.Exponential), { TextTransparency = 1 }):Play()
			end
			if modalParts.CancelStroke then
				tweenservice:Create(modalParts.CancelStroke, TweenInfo.new(1, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
			end
			task.wait(0.6)
			ModalInstance:Destroy()
		end



		if activeModals == 1 and dimOverlay then
			dimOverlay.Visible = true
			tweenservice:Create(dimOverlay, TweenInfo.new(0.73, Enum.EasingStyle.Exponential), {
				BackgroundTransparency = 0.3
			}):Play()
		end

		sydeConnectClick(modalParts.Confirm, function()
			if typeof(ModalData.ConfirmCallBack) == "function" then
				ModalData.ConfirmCallBack()
			end

			closeModal()

			if activeModals == 0 and dimOverlay then
				tweenservice:Create(dimOverlay, TweenInfo.new(0.73, Enum.EasingStyle.Exponential), {
					BackgroundTransparency = 1
				}):Play()
				task.wait(0.6)
				dimOverlay.Visible = false
			end
		end)

		sydeConnectClick(modalParts.Cancel, function()
			if typeof(ModalData.CancelCallBack) == "function" then
				ModalData.CancelCallBack()
			end
			closeModal()
			if activeModals == 0 and dimOverlay then
				tweenservice:Create(dimOverlay, TweenInfo.new(0.73, Enum.EasingStyle.Exponential), {
					BackgroundTransparency = 1
				}):Play()
				task.wait(0.6)
				dimOverlay.Visible = false
			end
		end)

	end)
end

