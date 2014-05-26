var shinyFiles = (function() {
	var elementSelector = function(element, single, forceSelect) {
		var parent = $(element).parent();
		var lastSelectedElement = parent.data('lastElement');
	
		
		function toggleSelection(element) {
		    $(element).toggleClass('selected');
		    parent.data('lastElement', element);
		}
		
		function selectElementsBetweenIndexes(indexes) {
			var els = parent.children();
		    indexes.sort(function(a, b) {
		        return a - b;
		    });
		
		    for (var i = indexes[0]; i <= indexes[1]; i++) {
		        $(els[i]).addClass('selected');
		    }
		}
		
		function clearAll() {
			parent.children().removeClass('selected');
		}
	
	    if (window.event.button === 0) {
	        if ((!window.event.metaKey && !window.event.ctrlKey && !window.event.shiftKey) || single) {
	        	var selected = $(element).hasClass('selected');
	        	var nSelected = parent.children('.selected').length;
	            clearAll();
	            if ((!selected || nSelected != 1) || forceSelect) {
	        	    toggleSelection(element);		            
	            }
	        } else if ((window.event.metaKey || window.event.ctrlKey) && !single) {
		        toggleSelection(element);
		    } else if (window.event.shiftKey && !single) {
	            selectElementsBetweenIndexes([$(lastSelectedElement).index(), $(element).index()])
	        }
	    }
	};
	var parseDir = function(data) {
		var parsedFiles = {};
		data.files.filename.forEach(function(d, i) {
			var mTime = data.files.mtime[i].split('-');
			var cTime = data.files.ctime[i].split('-');
			var aTime = data.files.atime[i].split('-');
			parsedFiles[d] = {
				name: d,
				extension: data.files.extension[i],
				isDir: data.files.isdir[i],
				size: data.files.size[i],
				mTime: new Date(mTime[0], mTime[1], mTime[2], mTime[3], mTime[4]),
				cTime: new Date(cTime[0], cTime[1], cTime[2], cTime[3], cTime[4]),
				aTime: new Date(aTime[0], aTime[1], aTime[2], aTime[3], aTime[4])
			};
		});
		
		return {
			files: parsedFiles,
			location: data.breadcrumps
		};
	};
	var formatDate = function(date) {
		var monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
		var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
		
		if (typeof Intl == 'undefined') {
			return dayNames[date.getDay()]+' '+monthNames[date.getMonth()]+' '+date.getDate()+' '+date.getFullYear()+' '+date.getHours()+':'+("0" + date.getMinutes()).substr(-2);
		} else {
			return date.toLocaleString([], {weekday:'long', year:'numeric', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit'})
		}
	};
	
	// Following function taken from http://stackoverflow.com/questions/10420352/converting-file-size-in-bytes-to-human-readable - Mark's answer
	var formatSize = function(bytes, si) {
		var thresh = si ? 1000 : 1024;
		if(bytes < thresh) return bytes + ' B';
		var units = si ? ['kB','MB','GB','TB','PB','EB','ZB','YB'] : ['KiB','MiB','GiB','TiB','PiB','EiB','ZiB','YiB'];
		var u = -1;
		do {
			bytes /= thresh;
			++u;
		} while(bytes >= thresh);
		return bytes.toFixed(1)+' '+units[u];
	};
	
	var initializeButton = function(button) {
		var back = $(button).data('back') || [];
		var forward = $(button).data('forward') || [];
		var view = $(button).data('view') || '';
		
		$(button).data('back', back)
			.data('forward', forward)
			.data('view', view);
	};
	
	var setDisabledButtons = function(button, modal) {
		var back = $(button).data('back').length == 0;
		var forward = $(button).data('forward').length == 0;
		var up = $(modal).find('.sF-breadcrumps option').length == 1;
		
		$(modal).find('#sF-btn-back').prop('disabled', back);
		$(modal).find('#sF-btn-forward').prop('disabled', forward);
		$(modal).find('#sF-btn-up').prop('disabled', up);
	}
	
	var createFileChooser = function(button, title) {
		Shiny.unbindAll();
		
		$(button).prop('disabled', true);
		
		initializeButton(button);
		
		var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modal sF-modalContainer modal fade').css('display', 'block').append(
			$('<div>').addClass('modal-header').append(
				$('<button>', {html: '&times;', type: 'button'}).addClass('close')
					.on('click', function() {
						dismissFileChooser(button, modal)
					})
			).append(
				$('<h4>', {text: title}).addClass('sF-title modal-title')
			)
		).append(
			$('<div>').addClass('modal-body').append(
				$('<div>').addClass('sF-navigation btn-toolbar').append(
					$('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
						$('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-chevron-left')
						).on('click', function() {
							moveBack(button, modal);
						})
					).append(
						$('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-arrow-up')
						).on('click', function() {
							moveUp(button, modal);
						})
					).append(
						$('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-chevron-right')
						).on('click', function() {
							moveForward(button, modal);
						})
					)
				).append(
					$('<div>').addClass('btn-group btn-group-sm sF-view').append(
						$('<button>', {id: 'sF-btn-icon'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-th')
						)
					).append(
						$('<button>', {id: 'sF-btn-list'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-th-list')
						)
					).append(
						$('<button>', {id: 'sF-btn-detail'}).addClass('btn btn-default').append(
							$('<i>').addClass('icon-align-justify')
						)
					).on('click', 'button', function() {
						changeView(button, modal, $(this));
					})
				).append(
					$('<select>').addClass('sF-breadcrumps form-control input-sm').on('change', function() {
							moveToDir(button, modal, this);
						}).css({
							'width': 'calc(100% - 250px)',
							'margin-bottom': 0,
							'float': 'right'
						})
				)
			).append(
				$('<div>').addClass('sF-fileWindow').append(
					$('<div>').addClass('sF-fileList')
				).on('click', function() {
					modal.find('.sF-fileList .selected').toggleClass('selected');
				})
			)
		).append(
			$('<div>').addClass('sF-responseButtons modal-footer').append(
				$('<button>', {text: 'Cancel', type: 'button'}).addClass('btn btn-default')
					.on('click', function() {
						dismissFileChooser(button, modal);
					})
			).append(
				$('<button>', {text: 'Select', type: 'button'}).addClass('btn btn-primary')
					.on('click', function() {
						selectFiles(button, modal);
					})
			)
		).appendTo($('body'));
		

			
		
		
		
		var backdrop = $('<div>').addClass('modal-backdrop fade').appendTo($('body'));
		
		modal.data('backdrop', backdrop);
		modal.data('button', button);
		$(button).data('modal', modal);
		
		var view = $(button).data('view') || 'sF-btn-icon';
		changeView(button, modal, modal.find('#'+view));
		
		modal.on('change', function() {
			setDisabledButtons(button, modal);
		});
		
		setTimeout(function() {
			modal.addClass('in');
			backdrop.addClass('in');
		}, 1);
		
		Shiny.bindAll();
	};
	
	var createFileChooserBootstrap3 = function(button, title) {
		Shiny.unbindAll();
		
		$(button).prop('disabled', true);
		
		initializeButton(button);
		
		var modal = $('<div>', {id: $(button).attr('id')+'-modal'}).addClass('sF-modalContainer modal fade').css('display', 'block').append(
			$('<div>').addClass('sF-modal modal-dialog').append(
				$('<div>').addClass('modal-content').append(
					$('<div>').addClass('modal-header').append(
						$('<button>', {html: '&times;', type: 'button'}).addClass('close')
							.on('click', function() {
								dismissFileChooser(button, modal)
							})
					).append(
						$('<h4>', {text: title}).addClass('sF-title modal-title')
					)
				).append(
					$('<div>').addClass('modal-body').append(
						$('<div>').addClass('sF-navigation btn-toolbar').append(
							$('<div>').addClass('btn-group btn-group-sm sF-navigate').append(
								$('<button>', {id: 'sF-btn-back'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-chevron-left')
								).on('click', function() {
									moveBack(button, modal);
								})
							).append(
								$('<button>', {id: 'sF-btn-up'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-arrow-up')
								).on('click', function() {
									moveUp(button, modal);
								})
							).append(
								$('<button>', {id: 'sF-btn-forward'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-chevron-right')
								).on('click', function() {
									moveForward(button, modal);
								})
							)
						).append(
							$('<div>').addClass('btn-group btn-group-sm sF-view').append(
								$('<button>', {id: 'sF-btn-icon'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-th')
								)
							).append(
								$('<button>', {id: 'sF-btn-list'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-th-list')
								)
							).append(
								$('<button>', {id: 'sF-btn-detail'}).addClass('btn btn-default').append(
									$('<span>').addClass('glyphicon glyphicon-align-justify')
								)
							).on('click', 'button', function() {
								changeView(button, modal, $(this));
							})
						).append(
							$('<select>').addClass('sF-breadcrumps form-control input-sm').on('change', function() {
									moveToDir(button, modal, this);
								})
						)
					).append(
						$('<div>').addClass('sF-fileWindow').append(
							$('<div>').addClass('sF-fileList')
						).on('click', function() {
							modal.find('.sF-fileList .selected').toggleClass('selected');
						})
					)
				).append(
					$('<div>').addClass('sF-responseButtons modal-footer').append(
						$('<button>', {text: 'Cancel', type: 'button'}).addClass('btn btn-default')
							.on('click', function() {
								dismissFileChooser(button, modal);
							})
					).append(
						$('<button>', {text: 'Select', type: 'button'}).addClass('btn btn-primary')
							.on('click', function() {
								selectFiles(button, modal);
							})
					)
				)
			)
		).appendTo($('body'));
		
		var backdrop = $('<div>').addClass('modal-backdrop fade').appendTo($('body'));
		
		modal.data('backdrop', backdrop);
		modal.data('button', button);
		$(button).data('modal', modal);
		
		var view = $(button).data('view') || 'sF-btn-icon';
		changeView(button, modal, modal.find('#'+view));
		
		modal.on('change', function() {
			setDisabledButtons(button, modal);
		});
		
		setTimeout(function() {
			modal.addClass('in');
			backdrop.addClass('in');
		}, 1);
		
		Shiny.bindAll();
	};
	
	var removeFileChooser = function(button, modal) {
		Shiny.unbindAll();
		
		var modal = $(modal).removeClass('in');
		var backdrop = $(modal).data('backdrop').removeClass('in');
		
		setTimeout(function() {
			modal.remove();
			backdrop.remove();
			Shiny.bindAll();
		}, 300);
		$(button).prop('disabled', false)
			.data('modal', null);
	};
	
	var dismissFileChooser = function(button, modal) {
		removeFileChooser(button, modal);
		$(button).trigger('cancel');
	};
	
	var populateFileChooser = function(element, data) {
		var modal = $(element).data('modal');
		
		if(!modal) return;
		
		var single = $(element).data('selecttype') == 'single';
		modal.find('.sF-breadcrumps').find('option').remove();
		
		data.location.forEach(function(d, i) {
			modal.find('.sF-breadcrumps').append(
				$('<option>', {html: '&#127968; ' + data.location.slice(0, i+1).join(' > '), value: d}).data('location', data.location.slice(0, i+1))
			);
		});
		modal.find('.sF-breadcrumps').prop('selectedIndex', data.location.length-1)
		
		modal.find('.sF-fileList').children().remove();
		
		modal.find('.sF-fileList').append(
			$('<div>').addClass('sF-file-header').append(
				$('<div>').append(
					$('<div>').addClass('sF-file-icon')
				).append(
					$('<div>', {text: 'name'}).addClass('sF-file-name')
				).append(
					$('<div>', {text: 'size'}).addClass('sF-file-size')
				).append(
					$('<div>', {text: 'modified'}).addClass('sF-file-mTime')
				).append(
					$('<div>', {text: 'created'}).addClass('sF-file-cTime')
				).append(
					$('<div>', {text: 'accessed'}).addClass('sF-file-aTime')
				)
			)
		);
		
		for (i in data.files) {
			var d = data.files[i];
			
			modal.find('.sF-fileList').append(
				$('<div>').toggleClass('sF-file', !d.isDir).toggleClass('sF-directory', d.isDir).append(
					$('<div>').addClass('sF-file-icon').addClass('sF-filetype-'+d.extension)
				).append(
					$('<div>').addClass('sF-file-name').append(
						$('<span>',  {text: d.name})
					)
				).append(
					$('<div>', {text: d.isDir ? '' : formatSize(d.size, true)}).addClass('sF-file-size')
				).append(
					$('<div>', {text: formatDate(d.mTime)}).addClass('sF-file-mTime')
				).append(
					$('<div>', {text: formatDate(d.cTime)}).addClass('sF-file-cTime')
				).append(
					$('<div>', {text: formatDate(d.aTime)}).addClass('sF-file-aTime')
				).data('sF-file', d).on('click', function() {
					elementSelector(this, single, false)
					return false;
				})
			).append('<i> </i>');
		};
		modal.find('.sF-directory').on('dblclick', function() {
			$(this).toggleClass('selected', true);
			openDir($(element), modal, this);
		});
		
		setDisabledButtons($(element), modal);
		
		$(modal).trigger('change');
	};
	
	var getSelectedFiles = function(modal) {
		var directory = getCurrentDirectory(modal);
		
		return modal.find('.sF-fileList').find('.selected .sF-file-name').map(function() {
			var dirCopy = directory.slice();
			dirCopy.push($(this).text());
			return dirCopy;
		});
	};
	
	var getCurrentDirectory = function(modal) {
		return modal.find('.sF-breadcrumps').find('option').map(function() {
			return $(this).val();
		});
	};
	
	var selectFiles = function(button, modal) {
		var files = getSelectedFiles(modal);
		
		$(button).data('files', files);
		$(button).trigger('fileselect', [files]);
		
		removeFileChooser(button, modal);
	};
	
	var changeView = function(button, modal, view) {
		modal.find('.sF-view button').toggleClass('active', false);
		view.toggleClass('active', true);
		
		var detail = false;
		var icons = false;
		var list = false;
		
		switch (view.attr('id')) {
			case 'sF-btn-icon':
				icons = true;
				break;
			case 'sF-btn-list' :
				list = true;
				break;
			case 'sF-btn-detail' :
				detail = true;
				break;
		}
		
		modal.find('.sF-fileList').toggleClass('sF-detail', detail)
			.toggleClass('sF-icons', icons)
			.toggleClass('sF-list', list);
		
		$(button).data('view', view.attr('id'));
	}
	
	var changeDirectory = function(button, modal, directory) {
		if (directory instanceof jQuery) directory = directory.toArray();
		
		$(button).data('path', directory);
		$(modal).trigger('navigate');
	};
	
	var moveBack = function(button, modal) {
		$('.sF-btn-back').prop('disabled', true);
		
		var newDir = $(button).data('back').pop();
		var currentDir = getCurrentDirectory(modal);
		
		changeDirectory(button, modal, newDir);
		$(button).data('forward').push(currentDir);
	};
	
	var moveForward = function(button, modal) {
		$('.sF-btn-forward').prop('disabled', true);
		
		var newDir = $(button).data('forward').pop();
		var currentDir = getCurrentDirectory(modal);
		
		changeDirectory(button, modal, newDir);
		$(button).data('back').push(currentDir);
	};
	
	var moveUp = function(button, modal) {
		$('.sF-btn-up').prop('disabled', true);
		
		var currentDir = getCurrentDirectory(modal);
		var newDir = currentDir.slice(0, -1);
		
		changeDirectory(button, modal, newDir);
		$(button).data('back').push(currentDir);
		$(button).data('forward', []);
	};
	
	var moveToDir = function(button, modal, select) {
		var currentDir = getCurrentDirectory(modal);
		var newDir = $($(select).find('option')[$(select).prop('selectedIndex')]).data('location')
		
		changeDirectory(button, modal, newDir);
		$(button).data('back').push(currentDir);
		$(button).data('forward', []);
	};
	
	var openDir = function(button, modal, dir) {
		var currentDir = getCurrentDirectory(modal);
		var newDir = currentDir.slice();
		newDir.push($(dir).find('.sF-file-name').text());
		
		changeDirectory(button, modal, newDir);
		$(button).data('back').push(currentDir);
		$(button).data('forward', []);
	}
	
	var sF = {};
	
	sF.init = function() {
		$(document).on('dirChange', '.shinyFiles', function(e, data) {
			populateFileChooser($(this), data);
		});
		
		$(document).on('click', '.shinyFiles', function(e) {
			createFileChooser(this, $(this).data('title'))
		})
	};
	sF.updateFileList = function(element, data) {
		$(element).trigger('dirChange', [parseDir(data)]);
	};
	
	return sF;
})()

$(document).ready(function() {
	shinyFiles.init();
})


var navigate = new Shiny.InputBinding();
$.extend(navigate, {
	find: function(scope) {
		return $(scope).find(".sF-modalContainer");
	},
	getValue: function(el) {
		return $($(el).data('button')).data('path') ? $($(el).data('button')).data('path') : null;
	},
	setValue: function(el, value) {
		$(el).data('path', value);
	},
	subscribe: function(el, callback) {
		$(el).on("navigate.shinyFiles", function(e) {
			callback();
		});
	},
	unsubscribe: function(el) {
		$(el).off(".shinyFiles");
	}
});

Shiny.inputBindings.register(navigate, 'shinyFiles.navigate');


var filechoose = new Shiny.InputBinding();
$.extend(filechoose, {
	find: function(scope) {
		return $(scope).find(".shinyFiles");
	},
	getValue: function(el) {
		return $(el).data('files') ? $.extend({}, $(el).data('files').toArray().map(function(d) {
			return d.toArray();
		})) : null;
	},
	setValue: function(el, value) {
		$(el).data('files', value);
	},
	subscribe: function(el, callback) {
		$(el).on("fileselect.shinyFiles", function(e) {
			callback();
		});
	},
	unsubscribe: function(el) {
		$(el).off(".shinyFiles");
	}
});

Shiny.inputBindings.register(filechoose, 'shinyFiles.filechoose');


var getFiles = new Shiny.OutputBinding();
$.extend(getFiles, {
	find: function(scope) {
		return $(scope).find(".shinyFiles");
	},
	renderValue: function(el, data) {
		if (data) {
			shinyFiles.updateFileList(el, data);
		}
	}
});

Shiny.outputBindings.register(getFiles, 'shinyFiles.getFiles');
