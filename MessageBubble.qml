import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "linkify.js" as Links

// Una burbuja de mensaje. No conoce el ListView ni el estado de la vista:
// recibe el mensaje resuelto y emite señales para lo que vive en ChatView.
Item {
    id: bubbleRow
    required property var entry
    required property var service
    property bool highlighted: false
    property bool narrow: false
    required property bool groupFirst
    required property bool groupLast
    readonly property string groupPos: groupFirst && groupLast ? "single"
        : groupFirst ? "first" : groupLast ? "last" : "middle"

    signal mediaRequested(string path)
    signal reactionRequested(var msg)
    signal deleteRequested(var msg)
    signal editRequested(var msg)
    signal mediaOpenRequested(var msg)
    signal mediaSaveRequested(var msg)

    readonly property var modelData: entry
    implicitHeight: bubble.height + (groupLast ? Theme.spacingS : Theme.spacingXXS)

    // Menú de la burbuja. El composer tiene el suyo (copiar/cortar/pegar) en ChatView.
    component MenuEntry: Controls.MenuItem {
        id: entry
        implicitHeight: 36
        leftPadding: Theme.spacingM
        rightPadding: Theme.spacingM
        contentItem: Label {
            text: entry.text
            color: entry.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            opacity: entry.enabled ? 1 : 0.5
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.NoWrap
        }
        background: Rectangle { radius: Theme.cornerRadius; color: entry.highlighted ? Theme.surfaceContainerHigh : "transparent" }
    }
    component TextMenu: Controls.Menu {
        id: textMenu
        required property var editor
        property bool allowReply: false
        property bool allowEdit: false
        signal replyRequested()
        signal deleteRequested()
        signal editRequested()
        width: 210
        padding: Theme.spacingXS
        popupType: Controls.Popup.Item
        background: Rectangle { radius: Theme.cornerRadius; color: Theme.surfaceContainer; border.color: Theme.outline; border.width: 1 }
        MenuEntry { visible: textMenu.allowReply; height: visible ? implicitHeight : 0; text: I18n.trFor("dankChat", "Reply"); onTriggered: textMenu.replyRequested() }
        MenuEntry { visible: textMenu.allowEdit; height: visible ? implicitHeight : 0; text: I18n.trFor("dankChat", "Edit message"); onTriggered: textMenu.editRequested() }
        MenuEntry { visible: textMenu.allowReply; height: visible ? implicitHeight : 0; text: I18n.trFor("dankChat", "Delete message…"); enabled: !bubbleRow.service.demo && !bubbleRow.service.writing; onTriggered: textMenu.deleteRequested() }
        MenuEntry { text: I18n.trFor("dankChat", "Copy"); enabled: textMenu.editor.selectedText.length > 0; onTriggered: textMenu.editor.copy() }
        MenuEntry { text: I18n.trFor("dankChat", "Select all"); enabled: textMenu.editor.length > 0; onTriggered: textMenu.editor.selectAll() }
    }

    // ChatView define estos componentes localmente; un .qml aparte no los hereda.
    component Label: StyledText { textFormat: Text.PlainText; color: Theme.surfaceText }
    component Action: DankActionButton { circular: false; iconColor: Theme.surfaceText; Accessible.name: tooltipText }


    readonly property bool outMsg: !!modelData.out
    readonly property bool tail: groupPos === "single" || groupPos === "last"
    readonly property bool hasMedia: !!modelData.mediaType && modelData.mediaType !== "webpage"
    readonly property real pad: Theme.spacingM
    // ponytail: ancho por TextMetrics; si el texto enriquecido envuelve raro, sube el +8 a +16
    readonly property real maxBubbleWidth: Math.min(
        width - 2 * Theme.spacingL, Math.max(180, width * (narrow ? 0.86 : 0.74)))

    TextMetrics {
        id: bubbleTextMetrics
        text: bubbleRow.modelData.text || ""
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
    }

    Rectangle {
        id: bubble
        readonly property color readableText: Links.readable(color, Theme.surfaceText, Theme.primaryText)
        readonly property color readableSecondary: Links.readable(color, Theme.surfaceVariantText, readableText)
        readonly property color readableAccent: Links.readable(color, Theme.primary, readableText)
        width: bubbleRow.hasMedia ? bubbleRow.maxBubbleWidth
            : Math.min(bubbleRow.maxBubbleWidth, Math.max(140, Math.ceil(bubbleTextMetrics.advanceWidth) + 2 * bubbleRow.pad))
        height: bubbleContent.implicitHeight + Theme.spacingS + Theme.spacingXS
        anchors.right: bubbleRow.outMsg ? parent.right : undefined
        anchors.left: bubbleRow.outMsg ? undefined : parent.left
        radius: Theme.cornerRadiusLarge
        topLeftRadius: !bubbleRow.outMsg && bubbleRow.groupPos !== "single" ? 6 : Theme.cornerRadiusLarge
        topRightRadius: bubbleRow.outMsg && bubbleRow.groupPos !== "single" ? 6 : Theme.cornerRadiusLarge
        bottomLeftRadius: !bubbleRow.outMsg && bubbleRow.tail ? 6 : Theme.cornerRadiusLarge
        bottomRightRadius: bubbleRow.outMsg && bubbleRow.tail ? 6 : Theme.cornerRadiusLarge
        color: bubbleRow.modelData.out ? Theme.primaryContainer : Theme.surfaceContainerHigh
        border.width: bubbleRow.highlighted ? 2 : 0
        border.color: Theme.primary
        ColumnLayout {
            id: bubbleContent
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.leftMargin: bubbleRow.pad; anchors.rightMargin: bubbleRow.pad
            anchors.topMargin: Theme.spacingS; anchors.bottomMargin: Theme.spacingXS
            spacing: Theme.spacingXS
            Label { Layout.fillWidth: true; wrapMode: Text.NoWrap; elide: Text.ElideRight; visible: !bubbleRow.outMsg && bubbleRow.groupFirst && !!bubbleRow.modelData.sender; text: bubbleRow.modelData.sender || ""; color: bubble.readableAccent; font.pixelSize: Theme.fontSizeSmall }
            Label {
                Layout.fillWidth: true
                visible: !!bubbleRow.modelData.replyText || !!bubbleRow.modelData.replyId
                text: "↳ " + (bubbleRow.modelData.replyText || I18n.trFor("dankChat", "Original message"))
                maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.Wrap
                color: bubble.readableSecondary; font.pixelSize: Theme.fontSizeSmall
                MouseArea {
                    anchors.fill: parent
                    enabled: !!bubbleRow.modelData.replyId
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bubbleRow.service.jumpToReply(bubbleRow.modelData.replyId)
                }
            }
            Loader {
                id: mediaPreviewLoader
                Layout.fillWidth: true
                active: !!bubbleRow.modelData.mediaType && bubbleRow.modelData.mediaType !== "webpage"
                visible: active
                Component.onCompleted: {
                    setSource(Qt.resolvedUrl("MediaPreview.qml") + "?revision=" + bubbleRow.service.viewRevision, {
                        message: Qt.binding(() => bubbleRow.modelData),
                        service: bubbleRow.service,
                        foregroundColor: Qt.binding(() => bubble.readableSecondary)
                    });
                }
                Connections {
                    target: mediaPreviewLoader.item
                    function onImageRequested(path) { bubbleRow.mediaRequested(path) }
                }
            }
            Controls.TextArea {
                id: messageText
                Layout.fillWidth: true
                visible: !!bubbleRow.modelData.text
                text: Links.render(bubbleRow.modelData.text, bubble.readableAccent)
                textFormat: TextEdit.RichText
                onLinkActivated: link => { if (Links.isWebUrl(link)) Qt.openUrlExternally(link); }
                readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                padding: 0; color: bubble.readableText; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMedium
                background: null
                selectionColor: Theme.primary
                selectedTextColor: Theme.primaryText
                Controls.ContextMenu.menu: TextMenu {
                    editor: messageText
                    allowReply: true
                    allowEdit: bubbleRow.modelData.out && !!bubbleRow.modelData.text
                    onEditRequested: bubbleRow.editRequested(bubbleRow.modelData)
                    onReplyRequested: bubbleRow.service.setReply(bubbleRow.modelData)
                    onDeleteRequested: bubbleRow.deleteRequested(bubbleRow.modelData)
                }
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                visible: (bubbleRow.modelData.reactions || []).length > 0
                spacing: 4
                Repeater {
                    model: bubbleRow.modelData.reactions || []
                    delegate: Controls.ItemDelegate {
                        id: reactionChip
                        required property var modelData
                        objectName: "reactionChip"
                        width: implicitWidth; height: 28
                        padding: 5
                        enabled: !bubbleRow.service.demo && bubbleRow.modelData.canReact !== false && !modelData.custom && !bubbleRow.service.reacting?.[bubbleRow.service.selectedChat?.key + ":" + bubbleRow.modelData.id]
                        Accessible.name: modelData.emoji + " " + modelData.count + (modelData.chosen ? " " + I18n.trFor("dankChat", "Your reaction") : "")
                        background: Rectangle { radius: height / 2; color: reactionChip.modelData.chosen ? Theme.primary : Theme.surfaceContainerHigh }
                        contentItem: Label { text: reactionChip.modelData.emoji + " " + reactionChip.modelData.count; color: reactionChip.modelData.chosen ? Theme.primaryText : Theme.surfaceText; elide: Text.ElideNone; wrapMode: Text.NoWrap }
                        onClicked: bubbleRow.service.reactToMessage(bubbleRow.modelData, modelData.chosen ? "" : modelData.emoji, bubbleRow.service.selectedChat)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                Item { Layout.fillWidth: true }
                Label { visible: !!bubbleRow.modelData.edited; text: I18n.trFor("dankChat", "Edited"); font.pixelSize: Theme.fontSizeSmall; color: bubble.readableSecondary }
                Label { text: bubbleRow.modelData.time || (bubbleRow.modelData.timestamp ? Qt.formatDateTime(new Date(bubbleRow.modelData.timestamp * 1000), "hh:mm") : ""); color: bubble.readableSecondary; font.pixelSize: Theme.fontSizeSmall }
                DankIcon {
                    id: deliveryIcon
                    readonly property string statusText: bubbleRow.modelData.deliveryPartial
                        ? I18n.trFor("dankChat", "Confirmed by at least one group participant")
                        : bubbleRow.modelData.deliveryStatus === "read" ? I18n.trFor("dankChat", "Read")
                        : bubbleRow.modelData.deliveryStatus === "delivered" ? I18n.trFor("dankChat", "Delivered")
                        : I18n.trFor("dankChat", "Sent")
                    visible: bubbleRow.modelData.out && !!bubbleRow.modelData.deliveryStatus
                    name: ["read", "delivered"].includes(bubbleRow.modelData.deliveryStatus) ? "done_all" : "check"
                    size: 16
                    color: bubbleRow.modelData.deliveryStatus === "read" ? bubble.readableAccent : bubble.readableSecondary
                }
            }
        }
    }

    // Un único handler en la raíz: los botones de la píldora tienen su propio hover y
    // al pasar el puntero sobre ellos se lo robaban a la burbuja, así que la píldora
    // aparecía y desaparecía. La visibilidad se decide por geometría, no por quién
    // tenga el hover.
    HoverHandler { id: rowHover }

    // Zona de las acciones: la burbuja más la franja donde flota la píldora.
    readonly property bool actionsShown: {
        if (!rowHover.hovered) return false;
        const p = rowHover.point.position;
        const inside = item => p.x >= item.x && p.x <= item.x + item.width
            && p.y >= item.y && p.y <= item.y + item.height;
        return inside(bubble) || inside(hoverBar);
    }

    // Acciones al hover. El menú contextual del texto y el "⋮" conservan el resto.
    Rectangle {
        id: hoverBar
        visible: bubbleRow.actionsShown || messageMenu.opened
        // Encima de la burbuja, pegado a su esquina: flota sobre el borde superior.
        anchors.right: bubbleRow.outMsg ? bubble.right : undefined
        anchors.left: bubbleRow.outMsg ? undefined : bubble.left
        anchors.top: bubble.top
        anchors.topMargin: -14
        z: 2
        height: 32
        width: hoverRow.implicitWidth + 2 * Theme.spacingXS
        radius: height / 2
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outlineVariant

        RowLayout {
            id: hoverRow
            anchors.centerIn: parent
            spacing: 0
            Action {
                iconName: "add_reaction"; width: 28; height: 28; iconSize: 16
                iconColor: bubble.readableSecondary
                tooltipText: I18n.trFor("dankChat", "React with emoji")
                visible: bubbleRow.modelData.canReact !== false
                enabled: !bubbleRow.service.demo && !bubbleRow.service.reacting?.[bubbleRow.service.selectedChat?.key + ":" + bubbleRow.modelData.id]
                onClicked: bubbleRow.reactionRequested(bubbleRow.modelData)
            }
            Action {
                iconName: "reply"; width: 28; height: 28; iconSize: 16
                iconColor: bubble.readableSecondary
                tooltipText: I18n.trFor("dankChat", "Reply")
                onClicked: bubbleRow.service.setReply(bubbleRow.modelData)
            }
            Action {
                iconName: "more_vert"; width: 28; height: 28; iconSize: 16
                iconColor: bubble.readableSecondary
                objectName: "messageMoreActions"
                Accessible.name: tooltipText
                tooltipText: "…"
                onClicked: messageMenu.popup()
            }
        }
    }

    Controls.Menu {
        id: messageMenu
        popupType: Controls.Popup.Item
        width: 200
        padding: Theme.spacingXS
        background: Rectangle { radius: Theme.cornerRadius; color: Theme.surfaceContainer; border.color: Theme.outline; border.width: 1 }
        MenuEntry {
            visible: !!bubbleRow.modelData.mediaPath
            text: I18n.trFor("dankChat", "Open media")
            onTriggered: bubbleRow.mediaOpenRequested(bubbleRow.modelData)
        }
        MenuEntry {
            visible: !!bubbleRow.modelData.mediaPath
            enabled: !bubbleRow.service.demo
            text: I18n.trFor("dankChat", "Save media as…")
            onTriggered: bubbleRow.mediaSaveRequested(bubbleRow.modelData)
        }
        MenuEntry {
            text: I18n.trFor("dankChat", "React with emoji")
            visible: bubbleRow.modelData.canReact !== false
            enabled: !bubbleRow.service.demo && !bubbleRow.service.reacting?.[bubbleRow.service.selectedChat?.key + ":" + bubbleRow.modelData.id]
            onTriggered: bubbleRow.reactionRequested(bubbleRow.modelData)
        }
        MenuEntry { text: I18n.trFor("dankChat", "Reply"); onTriggered: bubbleRow.service.setReply(bubbleRow.modelData) }
        MenuEntry {
            text: I18n.trFor("dankChat", "Delete message…")
            enabled: !bubbleRow.service.demo && !bubbleRow.service.writing
            onTriggered: bubbleRow.deleteRequested(bubbleRow.modelData)
        }
    }

}
