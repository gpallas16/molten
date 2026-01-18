import QtQuick
import QtQuick.Layouts
import "../components"
import "../globals"

Item {
    id: root
    implicitWidth: 450
    implicitHeight: 350

    signal closeRequested()

    // Adaptive colors based on background
    AdaptiveColors {
        id: adaptiveColors
        region: "notch"
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Left side: Calendar
        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            
       
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                z: 1

                // Month/Year header
                RowLayout {
                    width: parent.width

                    Text {
                        text: "◀"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendar.month = (calendar.month - 1 + 12) % 12
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var months = ["January", "February", "March", "April", "May", "June",
                                          "July", "August", "September", "October", "November", "December"]
                            return months[calendar.month] + " " + calendar.year
                        }
                        color: adaptiveColors.textColor
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "▶"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calendar.month = (calendar.month + 1) % 12
                        }
                    }
                }

                // Day headers
                RowLayout {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Calendar grid
                QtObject {
                    id: calendar
                    property int month: new Date().getMonth()
                    property int year: new Date().getFullYear()
                    property int today: new Date().getDate()
                    property int currentMonth: new Date().getMonth()
                    property int currentYear: new Date().getFullYear()
                }

                Grid {
                    width: parent.width
                    columns: 7
                    spacing: 2

                    Repeater {
                        model: {
                            var firstDay = new Date(calendar.year, calendar.month, 1).getDay()
                            var daysInMonth = new Date(calendar.year, calendar.month + 1, 0).getDate()
                            var days = []
                            
                            for (var i = 0; i < firstDay; i++) days.push(0)
                            for (var i = 1; i <= daysInMonth; i++) days.push(i)
                            
                            return days
                        }

                        Item {
                            width: 24
                            height: 24
                            
                     
                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                color: {
                                    var isToday = modelData === calendar.today && 
                                                   calendar.month === calendar.currentMonth &&
                                                   calendar.year === calendar.currentYear
                                    return isToday ? adaptiveColors.textColor : adaptiveColors.subtleTextColor
                                }
                                font.pixelSize: 11
                                z: 1
                            }
                        }
                    }
                }
            }
        }

        // Right side: Events, Now Playing, Weather
        Column {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // Now Playing
            Item {
                width: parent.width
                height: 80
                
      
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    z: 1

                    Item {
                        width: 56
                        height: 56
                        
                      
                        Text {
                            anchors.centerIn: parent
                            text: State.mediaPlaying ? "🎵" : "⏸"
                            font.pixelSize: 24
                            z: 1
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: State.mediaTitle || "Nothing playing"
                            color: adaptiveColors.textColor
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: State.mediaArtist || "—"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }

            // Weather
            Item {
                width: parent.width
                height: 80
                
              

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    z: 1

                    Text {
                        text: State.weatherIcon === "weather-clear" ? "☀️" : "🌤"
                        font.pixelSize: 36
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: State.weatherTemp || "—"
                            color: adaptiveColors.textColor
                            font.pixelSize: 24
                            font.weight: Font.Bold
                        }
                        Text {
                            text: "Clear sky"
                            color: adaptiveColors.subtleTextColor
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Events
            Item {
                width: parent.width
                height: parent.height - 180
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    z: 1

                    Text {
                        text: "📅 Events"
                        color: adaptiveColors.textColor
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No upcoming events"
                        color: adaptiveColors.subtleTextColor
                        font.pixelSize: 11
                        visible: !State.upcomingEvents || State.upcomingEvents.length === 0
                    }
                }
            }
        }
    }
}
