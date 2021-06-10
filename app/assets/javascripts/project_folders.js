var tree;
var elementFolderIds = [];
var displayed_folder_id = 0;

// will it display an ISA breadcrumb?
const use_breadcrumb = false

function setupFoldersTree(dataJson, container_id, drop_accept_class) {
  $j("#" + container_id)
    .bind("loaded.jstree", function () {
      $j("#" + container_id + " .jstree-anchor").droppable({
        accept: "." + drop_accept_class,
        hoverClass: "folder_hover",
        tolerance: "pointer",
        drop: function (event, ui) {
          ui.draggable.data("rejected", true);
          var folder_element_id = $j(this).attr("id");
          var folder_id = $j("#" + container_id)
            .jstree(true)
            .get_node(folder_element_id).data.folder_id;
          item_dropped_to_folder(ui.draggable, folder_id);
        },
      });
    })
    .jstree({
      core: {
        data: dataJson,
      },
      plugins: ["separate"],
    })
    .on("activate_node.jstree", function (e, data) {
      var obj = $j(this).jstree(true).get_node(data.node.id).data;
      var parent = $j(this).jstree(true).get_node(data.node.parent).data;
      var folder_id = obj.folder_id;
      var project_id = obj.project_id;
      var id = obj.id;
      var type = obj.type;
      folder_id ? folder_clicked(folder_id, project_id) : item_clicked(type, id, parent);
    });
}

function remove_item_from_assay(item_element) {
  var project_id = item_element.data("project-id");
  var origin_folder_id = item_element.data("origin-folder-id");
  var path = "/projects/" + project_id + "/folders/" + origin_folder_id + "/remove_asset";

  $j.ajax({
    url: path,
    type: "POST",
    dataType: "script",
    data: {
      asset_id: item_element.data("asset-id"),
      asset_type: item_element.data("asset-class"),
      asset_element_id: item_element.attr("id"),
    },
  });
}

function setupAssayRemoveDropTarget(target_id) {
  $j("#" + target_id).droppable({
    accept: ".draggable_assay_folder_item",
    hoverClass: "folder_hover",
    tolerance: "pointer",
    drop: function (event, ui) {
      remove_item_from_assay(ui.draggable);
    },
  });
}

function updateFolderLabel(folder_id, new_label) {
  //this is a workaround to using rename_node, which loses the droppable.
  var tree_id = $j("li#folder_" + folder_id)
    .parents(".jstree")
    .attr("id");
  var selector = "#" + tree_id + " li#folder_" + folder_id + " a";
  var contents = $j(selector).contents();
  contents[contents.length - 1].nodeValue = new_label;
}

function setupAssetCardDraggable(card_class) {
  $j("." + card_class).draggable({
    revert: "invalid",
    opacity: 0.3,
    start: function (event, ui) {
      ui.helper.data("rejected", false);
      ui.helper.data("original-position", ui.helper.offset());
      if ($j("remove_from_assay_drop_area")) {
        $j("#remove_from_assay_drop_area").fadeIn(200);
      }
    },
    stop: function (event, ui) {
      if (ui.helper.data("rejected") === true) {
        ui.helper.offset(ui.helper.data("original-position"));
      }
      if ($j("remove_from_assay_drop_area")) {
        $j("#remove_from_assay_drop_area").fadeOut(200);
      }
    },
  });
}

function item_dropped_to_folder(item_element, dest_folder_id) {
  if (!dest_folder_id) {
    alert("Moving to this folder is not allowed!");
    return;
  }
  if (dest_folder_id != displayed_folder_id) {
    var folder_element_id = "folder_" + dest_folder_id;
    var project_id = item_element.data("project-id");
    var origin_folder_id = item_element.data("origin-folder-id");
    var path = "/projects/" + project_id + "/folders/" + origin_folder_id + "/move_asset_to";

    $j.ajax({
      url: path,
      type: "POST",
      dataType: "script",
      data: {
        asset_id: item_element.data("asset-id"),
        asset_type: item_element.data("asset-class"),
        dest_folder_id: dest_folder_id,
        dest_folder_element_id: folder_element_id,
        asset_element_id: item_element.attr("id"),
      },
    });
    var dest = $j("#" + folder_element_id + "_anchor span");
    var origin = $j("#folder_" + origin_folder_id + "_anchor span");
    bounce(dest, parseInt(dest.text()) + 1);
    bounce(origin, parseInt(origin.text()) - 1);
  } else {
    alert("The item is already in that folder.");
    return;
  }
}

function folder_clicked(folder_id, project_id) {
  hideAll();
  $j("#folder_contents").show();
  $j("#folder_contents").spinner("add");
  var path = "/projects/" + project_id + "/folders/" + folder_id + "/display_contents";
  displayed_folder_id = folder_id;
  $j.ajax({ url: path, cache: false, dataType: "script" });
}

function item_clicked(type, id, parent) {
  hideAll();
  if (type == "folder") $j("#folder_contents").show();
  else $j("#" + type + "_contents").show();
  if (use_breadcrumb) breadcrumb(type);
  selectedItem.id = id;
  selectedItem.type = type;
  selectedItem.parent = parent;

  switch (type) {
    case "assay":
    case "investigation":
    case "study": {
      $j.ajax({
        url: "/projects_folders/" + pid + "/render_sharing_form/" + id + "/type/" + type,
        dataType: "script" });
      break;
    }
  }
  if (type == "study") {
    loadFlowchart();
    loadDesign();

  } else if (type == "assay") load_samples(".sampleTable");
}

function hideAll() {
  $j("#project_contents").hide();
  $j("#folder_contents").hide();
  $j("#investigation_contents").hide();
  $j("#study_contents").hide();
  $j("#assay_contents").hide();
}

function bounce(item, text) {
  item.addClass("animate");
  setTimeout(function () {
    item.css("transform", "scale(2)");
    item.css("opacity", "0");
  }, 1);
  setTimeout(function () {
    item.css("transform", "scale(1)");
    item.css("opacity", "1");
    item.text(text);
  }, 300);
}

(function ($) {
  "use strict";
  $j.jstree.plugins.separate = function (options, parent) {
    this.redraw_node = function (obj, deep, callback, force_draw) {
      obj = parent.redraw_node.apply(this, arguments);
      var n = this.get_node(obj),
        d = document;
      if (obj) {
        if (n.original.count) {
          obj.childNodes[1].innerHTML +=
            " <span class='badge badge-secondary'>" + n.original.count + "</span>";
        }
        if (n.data.type) $j(obj.childNodes[1]).attr("_type", n.data.type);
        if (n.data.id) $j(obj.childNodes[1]).attr("_id", n.data.id);
        if (n.state.separate && n.state.separate.label) {
          var p = d.createElement("p");
          p.innerHTML = n.state.separate.label;
          p.className = "separator";
          if (n.state.separate.action) {
            var a = d.createElement("a");
            a.href = n.state.separate.action;
            a.className = "treeaction glyphicon glyphicon-plus";
            $j(a).attr("onclick", "add" + n.state.separate.label + "(this)");
            // obj.prepend(a);
            $j(p).prepend(a)
          }
          obj.prepend(p);
        }
      }
      return obj;
    };
  };
})(jQuery);
