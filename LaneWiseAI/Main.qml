pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root

    required property var controller

    width: 1360
    height: 920
    minimumWidth: 380
    minimumHeight: 720
    visible: true
    title: "LaneWise AI"
    color: "#081225"

    readonly property var appController: root.controller
    readonly property bool wideLayout: width >= 1120
    readonly property bool midLayout: width >= 760
    readonly property color surface: "#102543"
    readonly property color surfaceAlt: "#17335d"
    readonly property color border: "#27477f"
    readonly property color ink: "#f4f9ff"
    readonly property color mutedInk: "#9fb4d8"
    readonly property color accent: "#2f6df6"
    readonly property color accentSoft: "#17305d"
    readonly property color accentAlt: "#79e4ff"
    readonly property color success: "#6ae7bf"
    readonly property color successSoft: "#143f38"
    readonly property color warning: "#ffb366"
    readonly property color warningSoft: "#4d3116"
    readonly property color cardShadow: "#02081766"
    readonly property color darkPanel: "#0f1f3a"
    readonly property color darkPanelSoft: "#13284d"
    readonly property string bodyFont: "Segoe UI"
    readonly property int headerHeight: root.midLayout ? 84 : 74
    readonly property int footerHeight: root.midLayout ? 68 : 88
    readonly property int sidebarWidth: root.wideLayout ? 244 : 0
    property var destinationModel: []
    property var activeLaneDefaults: ({ "ready": false })

    background: Item {
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#07101f" }
                GradientStop { position: 0.55; color: "#0d1d37" }
                GradientStop { position: 1.0; color: "#12294d" }
            }
        }

        Rectangle {
            width: parent.width * 0.46
            height: parent.width * 0.46
            radius: width / 2
            color: "#173765"
            opacity: 0.75
            x: -width * 0.24
            y: -height * 0.1
        }

        Rectangle {
            width: parent.width * 0.38
            height: parent.width * 0.38
            radius: width / 2
            color: "#113a3d"
            opacity: 0.72
            x: parent.width - width * 0.72
            y: parent.height * 0.12
        }
    }

    function money(value) {
        if (value === undefined || value === null || isNaN(Number(value)))
            return "$0.00"
        return "$" + Number(value).toLocaleString(Qt.locale("en_US"), "f", 2)
    }

    function integerText(value) {
        if (value === undefined || value === null || isNaN(Number(value)))
            return "0"
        return Math.round(Number(value)).toLocaleString(Qt.locale("en_US"))
    }

    function decimalText(value, digits) {
        if (value === undefined || value === null || isNaN(Number(value)))
            return Number(0).toFixed(digits)
        return Number(value).toLocaleString(Qt.locale("en_US"), "f", digits)
    }

    function prettyLocation(value) {
        const textValue = String(value || "").trim()
        const parts = textValue.split(" ")
        if (parts.length < 2)
            return textValue
        const stateCode = parts.pop()
        return parts.join(" ") + ", " + stateCode
    }

    function prettyLaneLabel(value) {
        const textValue = String(value || "")
        const laneParts = textValue.split(" -> ")
        if (laneParts.length !== 2)
            return textValue
        return root.prettyLocation(laneParts[0]) + " -> " + root.prettyLocation(laneParts[1])
    }

    function cardWidth(totalWidth, columns, spacing) {
        const safeWidth = Math.max(320, totalWidth)
        return Math.floor((safeWidth - spacing * (columns - 1)) / columns)
    }

    function coefficientValue(unit, value) {
        if (unit === "$ per mile" || unit === "$ per kg")
            return "$" + decimalText(value, 3)
        return money(value)
    }

    function pricingQualityLabel() {
        if (!root.appController.trainingSummary.ready)
            return "Calibrating"

        const improvement = Number(root.appController.trainingSummary.lossImprovementPercent || 0)
        if (root.appController.trainingSummary.converged && improvement >= 90)
            return "Excellent"
        if (root.appController.trainingSummary.converged && improvement >= 75)
            return "Strong"
        if (improvement >= 50)
            return "Stable"
        return "Improving"
    }

    function pricingQualityMessage() {
        if (!root.appController.trainingSummary.ready)
            return "The pricing engine is still learning from shipment history."

        const quality = root.pricingQualityLabel()
        if (quality === "Excellent")
            return "Quotes are closely aligned with historical shipment behavior."
        if (quality === "Strong")
            return "Quotes are learning well and tracking the historical network with confidence."
        if (quality === "Stable")
            return "Quotes are usable and continuing to tighten around historical pricing patterns."
        return "Quotes are still improving as the model settles into the latest network data."
    }

    function pricingQualityColor() {
        const quality = root.pricingQualityLabel()
        if (quality === "Excellent")
            return root.success
        if (quality === "Strong")
            return root.accentAlt
        if (quality === "Stable")
            return "#9ad1ff"
        return root.warning
    }

    function refreshDestinationModel() {
        if (originBox.currentIndex < 0) {
            root.destinationModel = []
            root.activeLaneDefaults = ({ "ready": false })
            return
        }

        root.destinationModel = root.appController.destinationOptions(originBox.currentText)
        if (root.destinationModel.length > 0) {
            destinationBox.currentIndex = 0
            Qt.callLater(root.refreshLaneDefaults)
        } else {
            destinationBox.currentIndex = -1
            root.activeLaneDefaults = ({ "ready": false })
        }
    }

    function refreshLaneDefaults() {
        if (originBox.currentIndex < 0 || destinationBox.currentIndex < 0) {
            root.activeLaneDefaults = ({ "ready": false })
            return
        }

        const defaults = root.appController.laneDefaults(originBox.currentText, destinationBox.currentText)
        root.activeLaneDefaults = defaults
        if (!defaults.ready)
            return

        milesField.text = String(Math.round(Number(defaults.miles)))
        weightField.text = String(Math.round(Number(defaults.kilograms)))
        palletsBox.value = Math.max(1, Math.round(Number(defaults.pallets)))
        serviceBox.currentIndex = Number(defaults.defaultServiceLevel)
    }

    component SurfaceCard: Rectangle {
        radius: 18
        color: root.surface
        border.color: root.border
        border.width: 1
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 1
            radius: parent.radius
            color: "transparent"
            border.color: "#1c3764"
            border.width: 1
            opacity: 0.65
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: root.cardShadow
            border.width: 1
            opacity: 0.35
        }
    }

    component Pill: Rectangle {
        id: pillRoot

        property string label: ""
        property color fillColor: root.accentSoft
        property color textColor: root.accentAlt

        implicitWidth: pillText.implicitWidth + 20
        implicitHeight: 32
        radius: 16
        color: fillColor
        border.color: "transparent"

        Text {
            id: pillText
            anchors.centerIn: parent
            text: pillRoot.label
            color: pillRoot.textColor
            font.family: root.bodyFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    component AppButton: Button {
        id: buttonRoot

        property color fillColor: root.accent
        property color textColor: root.ink
        property color strokeColor: fillColor

        implicitHeight: 44
        implicitWidth: buttonLabel.implicitWidth + 28
        font.family: root.bodyFont
        font.pixelSize: 14
        leftPadding: 16
        rightPadding: 16
        topPadding: 10
        bottomPadding: 10

        background: Rectangle {
            radius: 12
            color: buttonRoot.down ? Qt.darker(buttonRoot.fillColor, 1.08) : buttonRoot.fillColor
            border.color: buttonRoot.strokeColor
            border.width: 1
        }

        contentItem: Text {
            id: buttonLabel
            text: buttonRoot.text
            color: buttonRoot.textColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: buttonRoot.font.family
            font.pixelSize: buttonRoot.font.pixelSize
            font.weight: Font.DemiBold
        }
    }

    component MetricCard: SurfaceCard {
        id: metricRoot

        property string title: ""
        property string value: ""
        property string detail: ""
        property color valueColor: root.ink

        implicitHeight: metricColumn.implicitHeight + 28

        Column {
            id: metricColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Text {
                width: parent.width
                text: metricRoot.title
                color: root.mutedInk
                font.family: root.bodyFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: metricRoot.value
                color: metricRoot.valueColor
                font.family: root.bodyFont
                font.pixelSize: 21
                font.weight: Font.Black
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: metricRoot.detail
                color: root.mutedInk
                font.family: root.bodyFont
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }

    component Sparkline: Canvas {
        property var values: []
        property color lineColor: root.accent
        property color fillColor: "#dbe8ff"
        property color gridColor: "#ccd9f2"

        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            if (!values || values.length < 2 || width <= 0 || height <= 0)
                return

            let minValue = Number(values[0])
            let maxValue = Number(values[0])
            for (let i = 1; i < values.length; ++i) {
                const currentValue = Number(values[i])
                minValue = Math.min(minValue, currentValue)
                maxValue = Math.max(maxValue, currentValue)
            }

            const leftPad = 8
            const topPad = 8
            const chartWidth = Math.max(1, width - leftPad * 2)
            const chartHeight = Math.max(1, height - topPad * 2)
            const range = Math.max(0.0001, maxValue - minValue)

            ctx.lineWidth = 1
            ctx.strokeStyle = gridColor
            for (let gridIndex = 0; gridIndex < 4; ++gridIndex) {
                const gridY = topPad + chartHeight * gridIndex / 3
                ctx.beginPath()
                ctx.moveTo(leftPad, gridY)
                ctx.lineTo(leftPad + chartWidth, gridY)
                ctx.stroke()
            }

            ctx.beginPath()
            for (let pointIndex = 0; pointIndex < values.length; ++pointIndex) {
                const x = leftPad + chartWidth * pointIndex / Math.max(1, values.length - 1)
                const ratio = (Number(values[pointIndex]) - minValue) / range
                const y = topPad + chartHeight - chartHeight * ratio
                if (pointIndex === 0)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }

            ctx.lineWidth = 3
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.strokeStyle = lineColor
            ctx.stroke()

            const lastX = leftPad + chartWidth
            const lastRatio = (Number(values[values.length - 1]) - minValue) / range
            const lastY = topPad + chartHeight - chartHeight * lastRatio
            ctx.beginPath()
            ctx.arc(lastX, lastY, 4, 0, Math.PI * 2)
            ctx.fillStyle = lineColor
            ctx.fill()

            ctx.lineTo(leftPad + chartWidth, topPad + chartHeight)
            ctx.lineTo(leftPad, topPad + chartHeight)
            ctx.closePath()
            ctx.fillStyle = fillColor
            ctx.fill()
        }
    }

    component ShellTab: Rectangle {
        id: shellTabRoot

        property string label: ""
        property bool active: false

        implicitWidth: shellTabText.implicitWidth + 28
        implicitHeight: 38
        radius: 19
        color: active ? "#173765" : "#0b1a31"
        border.color: active ? "#3f7fff" : "#18304f"
        border.width: 1

        Text {
            id: shellTabText
            anchors.centerIn: parent
            text: shellTabRoot.label
            color: shellTabRoot.active ? "#ffffff" : "#b6c8e8"
            font.family: root.bodyFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    component SideNavItem: Rectangle {
        id: sideNavRoot

        property string label: ""
        property string caption: ""
        property bool active: false

        implicitHeight: navContent.implicitHeight + 18
        radius: 16
        color: active ? "#12294d" : "transparent"
        border.color: active ? "#2f6df6" : "transparent"
        border.width: 1

        Rectangle {
            width: 6
            height: 34
            radius: 3
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: sideNavRoot.active ? "#79e4ff" : "#1d3e68"
        }

        Column {
            id: navContent
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 12
            anchors.topMargin: 9
            anchors.bottomMargin: 9
            spacing: 4

            Text {
                width: parent.width
                text: sideNavRoot.label
                color: sideNavRoot.active ? "#ffffff" : "#d9e6fb"
                font.family: root.bodyFont
                font.pixelSize: 14
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: sideNavRoot.caption
                color: sideNavRoot.active ? "#9fc7ff" : "#7f96ba"
                font.family: root.bodyFont
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        id: appHeader
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.headerHeight
        color: "#091426"
        border.color: "#17335d"
        border.width: 1
        z: 3

        Rectangle {
            anchors.fill: parent
            color: "#0b172a"
            opacity: 0.84
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#1a3559"
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18

            Row {
                id: brandRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 44
                    height: 44
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#1d4ed8" }
                        GradientStop { position: 1.0; color: "#0ea5c6" }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "LW"
                        color: "#ffffff"
                        font.family: root.bodyFont
                        font.pixelSize: 16
                        font.weight: Font.Black
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "LaneWise AI"
                        color: "#ffffff"
                        font.family: root.bodyFont
                        font.pixelSize: root.midLayout ? 20 : 18
                        font.weight: Font.Black
                    }

                    Text {
                        text: "Freight pricing platform"
                        color: "#8ea6cc"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        visible: root.midLayout
                    }
                }
            }

            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    implicitWidth: headerStatusRow.implicitWidth + 26
                    implicitHeight: 42
                    radius: 21
                    color: "#102543"
                    border.color: "#23426f"
                    border.width: 1
                    visible: root.midLayout

                    Row {
                        id: headerStatusRow
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 9
                            height: 9
                            radius: 4.5
                            color: root.appController.trainingInProgress ? root.warning : root.success
                        }

                        Text {
                            text: root.appController.trainingInProgress ? "Pricing sync in progress" : "US network live"
                            color: "#dce8fb"
                            font.family: root.bodyFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#12294d"
                    border.color: "#23426f"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "AI"
                        color: "#ffffff"
                        font.family: root.bodyFont
                        font.pixelSize: 14
                        font.weight: Font.Black
                    }
                }
            }

            Flow {
                anchors.left: brandRow.right
                anchors.right: headerActions.left
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.wideLayout
                clip: true

                Repeater {
                    model: ["Overview", "Pricing", "Quotes", "Analytics", "Developers"]

                    delegate: ShellTab {
                        required property string modelData

                        label: modelData
                        active: modelData === "Pricing"
                    }
                }
            }
        }
    }

    Rectangle {
        id: sideBar
        anchors.top: appHeader.bottom
        anchors.bottom: appFooter.top
        anchors.left: parent.left
        width: root.sidebarWidth
        color: "#091426"
        border.color: "#17335d"
        border.width: visible ? 1 : 0
        visible: root.wideLayout
        z: 2

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#1a3559"
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Column {
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width
                    text: "Workspace"
                    color: "#7f96ba"
                    font.family: root.bodyFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: "LaneWise AI"
                    color: "#ffffff"
                    font.family: root.bodyFont
                    font.pixelSize: 22
                    font.weight: Font.Black
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: "Rate intelligence for freight teams, shippers, and digital quote experiences."
                    color: "#8ea6cc"
                    font.family: root.bodyFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Repeater {
                    model: [
                        { "label": "Pricing Control", "caption": "Rate inputs and pricing logic", "active": true },
                        { "label": "Quote Requests", "caption": "Live shipment price creation", "active": false },
                        { "label": "Network Signals", "caption": "Lane behavior and shipment trends", "active": false },
                        { "label": "Performance", "caption": "Model quality and optimization", "active": false },
                        { "label": "Integrations", "caption": "CRM, TMS and customer channels", "active": false },
                        { "label": "Settings", "caption": "Branding, permissions and access", "active": false }
                    ]

                    delegate: SideNavItem {
                        required property var modelData

                        width: parent.width
                        label: modelData.label
                        caption: modelData.caption
                        active: modelData.active
                    }
                }
            }

            Rectangle {
                width: parent.width
                implicitHeight: sideBarStatusColumn.implicitHeight + 24
                radius: 18
                color: "#102543"
                border.color: "#23426f"
                border.width: 1

                Column {
                    id: sideBarStatusColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        width: parent.width
                        text: "Network readiness"
                        color: "#9fb4d8"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        width: parent.width
                        text: root.appController.hasModel ? "Pricing engine ready" : "Syncing historical data"
                        color: root.appController.hasModel ? "#ffffff" : "#ffd6a3"
                        font.family: root.bodyFont
                        font.pixelSize: 18
                        font.weight: Font.Black
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        text: root.appController.trainingSummary.converged
                              ? "Model coefficients are stable and customer quotes are using the latest trained weights."
                              : "Historical shipment data is still calibrating before the pricing workspace reaches full confidence."
                        color: "#8ea6cc"
                        font.family: root.bodyFont
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    Flickable {
        id: flickable
        anchors.top: appHeader.bottom
        anchors.bottom: appFooter.top
        anchors.left: root.wideLayout ? sideBar.right : parent.left
        anchors.right: parent.right
        anchors.margins: 18
        clip: true
        contentWidth: width
        contentHeight: pageColumn.height + 64
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Item {
            width: flickable.width
            height: pageColumn.height + 64

            Column {
                id: pageColumn
                width: Math.min(parent.width, 1220)
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                spacing: 18

                SurfaceCard {
                    width: parent.width
                    implicitHeight: showcaseColumn.implicitHeight + 34
                    color: root.darkPanelSoft

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#102543" }
                            GradientStop { position: 0.48; color: "#16325e" }
                            GradientStop { position: 1.0; color: "#15396d" }
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: -54
                        anchors.rightMargin: -26
                        width: 260
                        height: 260
                        radius: 130
                        color: "#0ea5c6"
                        opacity: 0.16
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: -96
                        anchors.bottomMargin: -86
                        width: 280
                        height: 180
                        radius: 90
                        color: "#1d4ed8"
                        opacity: 0.16
                    }

                    Column {
                        id: showcaseColumn
                        anchors.fill: parent
                        anchors.margins: 17
                        spacing: 18

                        Flow {
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: ["Pricing workspace", "Customer quotes", "Carrier network", "API ready"]

                                delegate: ShellTab {
                                    required property string modelData

                                    label: modelData
                                    active: modelData === "Pricing workspace"
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: 18

                            Column {
                                width: root.wideLayout ? parent.width * 0.62 : parent.width
                                spacing: 14

                                Text {
                                    width: parent.width
                                    text: "How your quote is priced"
                                    color: "#ffffff"
                                    font.family: root.bodyFont
                                    font.pixelSize: root.wideLayout ? 38 : 30
                                    font.weight: Font.Black
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: "LaneWise AI gives your team a production-grade pricing surface that explains the rate, captures shipment details, and returns a polished quote in one place."
                                    color: "#c9dcff"
                                    font.family: root.bodyFont
                                    font.pixelSize: 16
                                    wrapMode: Text.WordWrap
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 8

                                    Pill {
                                        label: root.integerText(root.appController.datasetSummary.rows) + " historical shipments"
                                    }

                                    Pill {
                                        label: root.integerText(root.appController.datasetSummary.uniqueLanes) + " connected lanes"
                                        fillColor: "#102543"
                                        textColor: "#dce8fb"
                                    }

                                    Pill {
                                        label: root.appController.trainingInProgress ? "Refreshing live pricing" : "Pricing ready"
                                        fillColor: root.appController.trainingInProgress ? root.warningSoft : root.successSoft
                                        textColor: root.appController.trainingInProgress ? root.warning : root.success
                                    }
                                }
                            }

                            Rectangle {
                                width: root.wideLayout ? parent.width * 0.38 - 18 : 0
                                implicitHeight: heroAsideColumn.implicitHeight + 24
                                radius: 20
                                color: "#0f1f3a"
                                border.color: "#27477f"
                                border.width: 1
                                visible: root.wideLayout

                                Column {
                                    id: heroAsideColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        width: parent.width
                                        text: "Executive snapshot"
                                        color: "#9fc7ff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 12
                                        font.weight: Font.Black
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.appController.trainingSummary.converged ? "Quotes are aligned with the latest shipment history." : "Pricing is still tightening around the current network."
                                        color: "#ffffff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 18
                                        font.weight: Font.Black
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.appController.statusText
                                        color: "#9fb4d8"
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }

                                    AppButton {
                                        text: "Refresh pricing"
                                        enabled: root.appController.dataReady && !root.appController.trainingInProgress
                                        onClicked: root.appController.trainBatch()
                                    }
                                }
                            }
                        }

                        Flow {
                            id: headerMetricsFlow
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: 4

                                delegate: MetricCard {
                                    required property int index

                                    width: root.cardWidth(headerMetricsFlow.width,
                                                          root.wideLayout ? 4 : (root.midLayout ? 2 : 1),
                                                          headerMetricsFlow.spacing)
                                    color: "#0f1f3a"
                                    title: index === 0 ? "Network records" :
                                           index === 1 ? "Typical shipment" :
                                           index === 2 ? "Current rate band" :
                                                         "Refresh status"
                                    value: index === 0 ? root.integerText(root.appController.datasetSummary.rows) :
                                           index === 1 ? root.integerText(root.appController.datasetSummary.avgDistance) + " mi" :
                                           index === 2 ? root.money(root.appController.datasetSummary.minCost) + " - " + root.money(root.appController.datasetSummary.maxCost) :
                                                         (root.appController.trainingSummary.converged ? "Healthy" : "Updating")
                                    detail: index === 0 ? root.integerText(root.appController.datasetSummary.uniqueLanes) + " active historical lanes" :
                                            index === 1 ? root.integerText(root.appController.datasetSummary.avgWeight) + " kg average freight weight" :
                                            index === 2 ? "Observed across the current shipment network" :
                                                          root.appController.trainingSummary.message
                                    valueColor: index === 3
                                                ? (root.appController.trainingSummary.converged ? root.success : root.warning)
                                                : root.ink
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: headerNoteColumn.implicitHeight + 22
                            radius: 18
                            color: "#0f1f3a"
                            border.color: "#27477f"
                            border.width: 1

                            Column {
                                id: headerNoteColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    width: parent.width
                                    text: "Pricing factors"
                                    color: root.accentAlt
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                    font.weight: Font.Black
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: "Distance and freight weight are normalized behind the scenes so the quote stays stable whether you are pricing a short regional lane or a long cross-country haul."
                                    color: root.ink
                                    font.family: root.bodyFont
                                    font.pixelSize: 14
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    width: parent.width
                                    text: "Current scaling: " + root.integerText(root.appController.trainingSummary.distanceScale) + " mi distance blocks and "
                                          + root.integerText(root.appController.trainingSummary.weightScale) + " kg weight blocks."
                                    color: root.mutedInk
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }

                SurfaceCard {
                    width: parent.width
                    implicitHeight: coefficientsColumn.implicitHeight + 32

                    Column {
                        id: coefficientsColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14

                        Text {
                            width: parent.width
                            text: "Price drivers"
                            color: root.ink
                            font.family: root.bodyFont
                            font.pixelSize: 20
                            font.weight: Font.Black
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "These pricing drivers show how the final quote responds to lane distance, freight size, handling effort, and service urgency."
                            color: root.mutedInk
                            font.family: root.bodyFont
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                        }

                        Flow {
                            id: coefficientFlow
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: root.appController.coefficients

                                delegate: SurfaceCard {
                                    id: coefficientCard
                                    required property var modelData

                                    width: root.cardWidth(coefficientFlow.width,
                                                          root.wideLayout ? 3 : (root.midLayout ? 2 : 1),
                                                          coefficientFlow.spacing)
                                    implicitHeight: coefficientColumn.implicitHeight + 24
                                    color: root.surfaceAlt

                                    Column {
                                        id: coefficientColumn
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 6

                                        Text {
                                            width: parent.width
                                            text: coefficientCard.modelData.label
                                            color: root.mutedInk
                                            font.family: root.bodyFont
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.coefficientValue(coefficientCard.modelData.unit,
                                                                        coefficientCard.modelData.businessValue)
                                            color: root.ink
                                            font.family: root.bodyFont
                                            font.pixelSize: 24
                                            font.weight: Font.Black
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            width: parent.width
                                            text: coefficientCard.modelData.unit
                                            color: root.mutedInk
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            width: parent.width
                                            text: coefficientCard.modelData.insight
                                            color: root.mutedInk
                                            font.family: root.bodyFont
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Flow {
                    id: quoteFlow
                    width: parent.width
                    spacing: 16

                    SurfaceCard {
                        id: quoteBuilderCard
                        width: root.cardWidth(quoteFlow.width,
                                              root.midLayout ? 2 : 1,
                                              quoteFlow.spacing)
                        implicitHeight: quoteFormColumn.implicitHeight + 32
                        color: root.surface

                        Column {
                            id: quoteFormColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Pill {
                                label: "Live quote builder"
                                fillColor: root.accentSoft
                                textColor: root.accentAlt
                            }

                            Text {
                                width: parent.width
                                text: "Build a shipment quote"
                                color: root.ink
                                font.family: root.bodyFont
                                font.pixelSize: 24
                                font.weight: Font.Black
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                width: parent.width
                                text: "Pick where the load starts and where it ends, then fine-tune the shipment profile to receive a customer-ready price."
                                color: root.mutedInk
                                font.family: root.bodyFont
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }

                            Flow {
                                id: formFields
                                width: parent.width
                                spacing: 12

                                Column {
                                    width: root.cardWidth(formFields.width,
                                                          root.midLayout ? 2 : 1,
                                                          formFields.spacing)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Origin"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    ComboBox {
                                        id: originBox
                                        width: parent.width
                                        model: root.appController.originOptions
                                        currentIndex: -1
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        palette.buttonText: root.ink
                                        palette.text: root.ink
                                        displayText: currentIndex >= 0 ? root.prettyLocation(currentText) : "Select origin"
                                        leftPadding: 12
                                        rightPadding: 32
                                        delegate: ItemDelegate {
                                            required property string modelData
                                            width: originBox.width
                                            text: root.prettyLocation(modelData)
                                            font.family: root.bodyFont
                                            palette.text: "black"
                                        }
                                        background: Rectangle {
                                            radius: 14
                                            color: root.surfaceAlt
                                            border.color: root.border
                                            border.width: 1
                                        }
                                        onActivated: root.refreshDestinationModel()
                                    }
                                }

                                Column {
                                    width: root.cardWidth(formFields.width,
                                                          root.midLayout ? 2 : 1,
                                                          formFields.spacing)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Destination"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    ComboBox {
                                        id: destinationBox
                                        width: parent.width
                                        model: root.destinationModel
                                        currentIndex: -1
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        palette.buttonText: root.ink
                                        palette.text: root.ink
                                        displayText: currentIndex >= 0 ? root.prettyLocation(currentText) : "Select destination"
                                        leftPadding: 12
                                        rightPadding: 32
                                        delegate: ItemDelegate {
                                            required property string modelData
                                            width: destinationBox.width
                                            text: root.prettyLocation(modelData)
                                            font.family: root.bodyFont
                                            palette.text: "black"
                                        }
                                        background: Rectangle {
                                            radius: 14
                                            color: root.surfaceAlt
                                            border.color: root.border
                                            border.width: 1
                                        }
                                        onActivated: root.refreshLaneDefaults()
                                    }
                                }

                                Column {
                                    width: root.cardWidth(formFields.width,
                                                          root.midLayout ? 2 : 1,
                                                          formFields.spacing)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Lane miles"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    TextField {
                                        id: milesField
                                        width: parent.width
                                        readOnly: true
                                        placeholderText: "Auto-filled from selected lane"
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        color: root.ink
                                        placeholderTextColor: root.mutedInk
                                        leftPadding: 12
                                        rightPadding: 12
                                        topPadding: 10
                                        bottomPadding: 10
                                        background: Rectangle {
                                            radius: 12
                                            color: root.darkPanelSoft
                                            border.color: root.border
                                            border.width: 1
                                        }
                                    }
                                }

                                Column {
                                    width: root.cardWidth(formFields.width, root.midLayout ? 2 : 1, formFields.spacing)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Weight (kg)"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    TextField {
                                        id: weightField
                                        width: parent.width
                                        placeholderText: "Auto-filled from lane average"
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        color: root.ink
                                        placeholderTextColor: root.mutedInk
                                        validator: DoubleValidator {
                                            bottom: 0
                                        }
                                        leftPadding: 12
                                        rightPadding: 12
                                        topPadding: 10
                                        bottomPadding: 10
                                        background: Rectangle {
                                            radius: 12
                                            color: root.surfaceAlt
                                            border.color: root.border
                                            border.width: 1
                                        }
                                    }
                                }
                            }

                            Flow {
                                width: parent.width
                                spacing: 12

                                Column {
                                    width: root.cardWidth(parent.width, root.wideLayout ? 3 : (root.midLayout ? 2 : 1), 12)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Pallets"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    SpinBox {
                                        id: palletsBox
                                        width: parent.width
                                        from: 1
                                        to: 24
                                        value: 12
                                        editable: true
                                        palette.text: root.ink
                                        palette.buttonText: root.ink
                                        background: Rectangle {
                                            radius: 14
                                            color: root.surfaceAlt
                                            border.color: root.border
                                            border.width: 1
                                        }
                                    }
                                }

                                Column {
                                    width: root.cardWidth(parent.width,
                                                          root.wideLayout ? 3 : (root.midLayout ? 2 : 1),
                                                          12)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Service quality"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    ComboBox {
                                        id: serviceBox
                                        width: parent.width
                                        model: ["Express", "Standard", "Economy"]
                                        currentIndex: 1
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        palette.buttonText: root.ink
                                        palette.text: "black"
                                        leftPadding: 12
                                        rightPadding: 32
                                        background: Rectangle {
                                            radius: 14
                                            color: root.surfaceAlt
                                            border.color: root.border
                                            border.width: 1
                                        }

                                    }
                                }

                                Column {
                                    width: root.cardWidth(parent.width,
                                                          root.wideLayout ? 3 : (root.midLayout ? 2 : 1),
                                                          12)
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Historical band"
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }

                                    Rectangle {
                                        width: parent.width
                                        implicitHeight: historicalBandText.implicitHeight + 20
                                        radius: 12
                                        color: root.surfaceAlt
                                        border.color: root.border
                                        border.width: 1

                                        Text {
                                            id: historicalBandText
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: root.activeLaneDefaults.ready
                                                  ? root.money(root.activeLaneDefaults.minCost) + " to " + root.money(root.activeLaneDefaults.maxCost)
                                                  : "Select a lane"
                                            color: root.ink
                                            font.family: root.bodyFont
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }

                            AppButton {
                                width: parent.width
                                text: "Generate quote"
                                enabled: root.appController.hasModel
                                         && !root.appController.trainingInProgress
                                         && root.activeLaneDefaults.ready
                                implicitHeight: 50
                                onClicked: {
                                    root.appController.generateQuoteForLane(originBox.currentText,
                                                                            destinationBox.currentText,
                                                                            Number(weightField.text || 0),
                                                                            palletsBox.value,
                                                                            serviceBox.currentIndex)
                                }
                            }
                        }
                    }

                    SurfaceCard {
                        id: quoteResultCard
                        width: root.cardWidth(quoteFlow.width,
                                              root.midLayout ? 2 : 1,
                                              quoteFlow.spacing)
                        implicitHeight: root.midLayout
                                        ? Math.max(quoteBuilderCard.implicitHeight, quoteResultColumn.implicitHeight + 32)
                                        : quoteResultColumn.implicitHeight + 32
                        color: root.surface

                        Column {
                            id: quoteResultColumn
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Pill {
                                label: root.appController.quoteResult.exactMatch ? "Historical lane price" : "Estimated lane price"
                                fillColor: root.appController.quoteResult.exactMatch ? root.successSoft : root.accentSoft
                                textColor: root.appController.quoteResult.exactMatch ? root.success : root.accentAlt
                            }

                            Text {
                                width: parent.width
                                text: "Quote result"
                                color: root.ink
                                font.family: root.bodyFont
                                font.pixelSize: 24
                                font.weight: Font.Black
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                width: parent.width
                                implicitHeight: resultSummary.implicitHeight + 24
                                radius: 20
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#1d4ed8" }
                                    GradientStop { position: 1.0; color: "#0ea5c6" }
                                }
                                border.color: "#3d7fff"
                                border.width: 1

                                Column {
                                    id: resultSummary
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: root.prettyLaneLabel(root.appController.quoteResult.label)
                                        color: "#d9ecff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.money(root.appController.quoteResult.predictedCost)
                                        color: "#ffffff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 42
                                        font.weight: Font.Black
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.integerText(root.appController.quoteResult.miles) + " mi | "
                                              + root.integerText(root.appController.quoteResult.kilograms) + " kg | "
                                              + root.integerText(root.appController.quoteResult.pallets) + " pallets | "
                                              + root.appController.quoteResult.serviceLabel
                                        color: "#eaf6ff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                implicitHeight: quoteMetaColumn.implicitHeight + 22
                                radius: 16
                                color: root.accentSoft
                                border.color: root.border
                                border.width: 1

                                Column {
                                    id: quoteMetaColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: root.activeLaneDefaults.ready
                                              ? root.prettyLaneLabel(root.activeLaneDefaults.label)
                                              : (root.appController.quoteResult.laneType ? root.appController.quoteResult.laneType : "Quote context")
                                        color: root.ink
                                        font.family: root.bodyFont
                                        font.pixelSize: 15
                                        font.weight: Font.Black
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.activeLaneDefaults.ready
                                              ? (root.activeLaneDefaults.exactMatch ? "Exact lane available | " : "Estimated lane profile | ")
                                                + root.integerText(root.activeLaneDefaults.shipmentCount) + " historical shipments | "
                                                + root.integerText(root.activeLaneDefaults.kilograms) + " kg avg weight | "
                                                + root.decimalText(root.activeLaneDefaults.pallets, 1) + " avg pallets | "
                                                + root.activeLaneDefaults.serviceLabel + " default service"
                                              : (root.appController.quoteResult.laneMessage ? root.appController.quoteResult.laneMessage : "Generated from the current freight profile.")
                                        color: root.mutedInk
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.activeLaneDefaults.ready ? root.activeLaneDefaults.laneMessage : ""
                                        color: root.accentAlt
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        visible: text.length > 0
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Historical band: "
                                              + root.money(root.appController.quoteResult.historicalLow)
                                              + " to "
                                              + root.money(root.appController.quoteResult.historicalHigh)
                                        color: root.accent
                                        font.family: root.bodyFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                SurfaceCard {
                    width: parent.width
                    implicitHeight: trendShowcaseColumn.implicitHeight + 32
                    color: root.darkPanel
                    border.color: "#1d3764"

                    Column {
                        id: trendShowcaseColumn
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Row {
                            width: parent.width
                            spacing: 10

                            Pill {
                                label: root.appController.trainingSummary.ready ? "Objective trend" : "Preparing rates"
                                fillColor: "#17305d"
                                textColor: "#d6e8ff"
                            }

                            Pill {
                                label: root.decimalText(root.appController.trainingSummary.lossImprovementPercent, 1) + "% improvement"
                                fillColor: "#113a3d"
                                textColor: "#8df1ee"
                            }
                        }

                        Text {
                            width: parent.width
                            text: "Pricing quality over training"
                            color: "#ffffff"
                            font.family: root.bodyFont
                            font.pixelSize: 24
                            font.weight: Font.Black
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            width: parent.width
                            text: "This view shows how the pricing model settles into a more stable quote profile as it learns from historical freight activity."
                            color: "#b8c7e2"
                            font.family: root.bodyFont
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: qualitySummaryColumn.implicitHeight + 22
                            radius: 18
                            color: root.darkPanelSoft
                            border.color: "#27477f"
                            border.width: 1

                            Column {
                                id: qualitySummaryColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Row {
                                    width: parent.width
                                    spacing: 12

                                    Rectangle {
                                        width: root.midLayout ? 180 : parent.width
                                        height: 84
                                        radius: 16
                                        color: "#102543"
                                        border.color: "#27477f"
                                        border.width: 1

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: "Pricing quality"
                                                color: "#9fb4d8"
                                                font.family: root.bodyFont
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.pricingQualityLabel()
                                                color: root.pricingQualityColor()
                                                font.family: root.bodyFont
                                                font.pixelSize: 28
                                                font.weight: Font.Black
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width - 192
                                        height: 84
                                        radius: 16
                                        color: "#102543"
                                        border.color: "#27477f"
                                        border.width: 1
                                        visible: root.midLayout

                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            text: root.pricingQualityMessage()
                                            color: "#d6e8ff"
                                            font.family: root.bodyFont
                                            font.pixelSize: 14
                                            wrapMode: Text.WordWrap
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8
                                    visible: !root.midLayout

                                    Text {
                                        width: parent.width
                                        text: root.pricingQualityMessage()
                                        color: "#d6e8ff"
                                        font.family: root.bodyFont
                                        font.pixelSize: 14
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Flow {
                                    width: parent.width
                                    spacing: 10

                                    Repeater {
                                        model: 3

                                        delegate: Rectangle {
                                            id: qualityMetricCard
                                            required property int index

                                            width: root.cardWidth(parent.width,
                                                                  root.midLayout ? 3 : 1,
                                                                  10)
                                            implicitHeight: qualityMetricColumn.implicitHeight + 18
                                            radius: 14
                                            color: "#102543"
                                            border.color: "#27477f"
                                            border.width: 1

                                            Column {
                                                id: qualityMetricColumn
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 4

                                                Text {
                                                    width: parent.width
                                                    text: qualityMetricCard.index === 0 ? "Error reduction" :
                                                          qualityMetricCard.index === 1 ? "Model state" :
                                                                        "Training passes"
                                                    color: "#9fb4d8"
                                                    font.family: root.bodyFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    wrapMode: Text.WordWrap
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: qualityMetricCard.index === 0 ? root.decimalText(root.appController.trainingSummary.lossImprovementPercent, 1) + "%" :
                                                          qualityMetricCard.index === 1 ? (root.appController.trainingSummary.converged ? "Converged" : "Learning") :
                                                                        root.integerText(root.appController.trainingSummary.iterations)
                                                    color: qualityMetricCard.index === 0 ? "#8df1ee" :
                                                           qualityMetricCard.index === 1 ? root.pricingQualityColor() :
                                                                         "#ffffff"
                                                    font.family: root.bodyFont
                                                    font.pixelSize: 22
                                                    font.weight: Font.Black
                                                    wrapMode: Text.WordWrap
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: qualityMetricCard.index === 0 ? "Lower error means quotes are matching freight history more closely." :
                                                          qualityMetricCard.index === 1 ? "Shows whether the current model has settled into a stable pricing state." :
                                                                        "Number of optimization updates used to tune customer pricing."
                                                    color: "#b8c7e2"
                                                    font.family: root.bodyFont
                                                    font.pixelSize: 12
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            implicitHeight: trendChartColumn.implicitHeight + 22
                            radius: 18
                            color: root.darkPanelSoft
                            border.color: "#27477f"
                            border.width: 1

                            Column {
                                id: trendChartColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Column {
                                        width: parent.width * 0.5 - 5
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: "Starting score"
                                            color: "#9fb4d8"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.decimalText(root.appController.trainingSummary.initialLoss, 2)
                                            color: "#ffffff"
                                            font.family: root.bodyFont
                                            font.pixelSize: 22
                                            font.weight: Font.Black
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    Column {
                                        width: parent.width * 0.5 - 5
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: "Current score"
                                            color: "#9fb4d8"
                                            font.family: root.bodyFont
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }

                                        Text {
                                            width: parent.width
                                            text: root.decimalText(root.appController.trainingSummary.finalLoss, 2)
                                            color: "#8df1ee"
                                            font.family: root.bodyFont
                                            font.pixelSize: 22
                                            font.weight: Font.Black
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                Sparkline {
                                    width: parent.width
                                    height: 220
                                    values: root.appController.objectiveHistory
                                    lineColor: "#79e4ff"
                                    fillColor: "#173765"
                                    gridColor: "#28497e"
                                }

                                Text {
                                    width: parent.width
                                    text: root.appController.trainingSummary.message
                                    color: "#b8c7e2"
                                    font.family: root.bodyFont
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: appFooter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.footerHeight
        color: "#091426"
        border.color: "#17335d"
        border.width: 1
        z: 3

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: "#1a3559"
        }

        Item {
            anchors.fill: parent
            anchors.margins: 16

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: "LaneWise AI"
                    color: "#ffffff"
                    font.family: root.bodyFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                }

                Text {
                    text: "Modern freight pricing surfaces for customer-ready digital quotes."
                    color: "#8ea6cc"
                    font.family: root.bodyFont
                    font.pixelSize: 12
                }
            }

            Flow {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: root.midLayout

                Repeater {
                    model: ["Security", "Status", "Docs", "Partners", "Contact"]

                    delegate: ShellTab {
                        required property string modelData

                        label: modelData
                        active: false
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (root.appController.originOptions.length > 0 && originBox.currentIndex < 0) {
            originBox.currentIndex = 0
            root.refreshDestinationModel()
        }
    }
}
