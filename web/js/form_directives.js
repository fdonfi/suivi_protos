var app = angular.module('FormDirectives');


/**
 * wrapper pour la directive typeahead permettant de l'utiliser en édition
 * requete inverse au serveur pour obtenir un label lié à l'ID fourni et passage
 * label à la directive pour affichage
 * params supplémentaires:
 *  initial -> l'ID fourni
 *  reverseurl -> l'url permettant d'obtenir le label correspondant à l'ID
 */
app.directive('angucompletewrapper', function(dataServ, $http){
    return {
        restrict: 'E',
        scope: {
            inputclass: '@',
            decorated: '@',
            selectedobject: '=',
            ngBlur: '=',
            url: '@',
            initial: '=',
            reverseurl: '@',
            ngrequired: '=',
        },
        transclude: true,
        templateUrl: 'js/templates/form/autoComplete.htm',
        link: function($scope, elem){
            $scope.localselectedobject = '';
            $scope.test = function(){
                if($('#aw')[0].value == ''){
                    $scope.selectedobject = null;
                }
            };

            $scope.find = function(txt){
                if(txt){
                    return $http.get($scope.url + txt).then(function(resp){
                        return resp.data;    
                    });
                }
            };

            $scope.$watch('localselectedobject', function(newval){
                if(newval && newval.id){
                    $scope.selectedobject = newval.id;
                    elem[0].firstChild.children[1].focus();
                }
            });

            $scope.$watch('initial', function(newval){
                if(newval){
                    dataServ.get($scope.reverseurl + '/' + newval, function(resp){
                        $scope.localselectedobject = resp;
                    });
                }
                else{
                    $scope.localselectedobject = null;
                }
            });
        }
    };
});


/**
 * génération automatique de formulaire à partir d'un json qui représente le schéma du formulaire
 * params:
 *  schema: le squelette du formulaire (cf. doc schémas)
 *  data: le dictionnaire de données source/cible
 *  errors: liste d'erreurs de saisie (dictionnaire {nomChamp: errMessage})
 */
app.directive('dynform', function(){
    return {
        restrict: 'E',
        scope: {
            group: '=',
            data: '=',
            errors: '=',
        },
        templateUrl: 'js/templates/form/dynform.htm',
        controller: function($scope){},
    };
});

app.directive('tableFieldset', function(){
    return {
        restrict: 'E',
        scope: {
            group: '=',
            data: '=',
            errors: '=',
        },
        templateUrl: 'js/templates/form/tableFieldset.htm',
        controller: function($scope){},
    };
});

/**
 * génération d'un champ formulaire de type multivalué
 * params:
 *  refer: la valeur source/cible du champ (une liste)
 *  schema: le schema descripteur du champ (cf. doc schemas)
 */
app.directive('multi', function(userMessages, $timeout){
    return {
        restrict: 'E',
        scope: {
            refer: '=',
            schema: '=',
        },
        templateUrl: 'js/templates/form/multi.htm',
        link: function($scope, elem){
            $scope.addDisabled = true;
            if(!$scope.refer){
                $scope.refer = [];
            }
            $scope.data = $scope.refer;
            $scope.$watch(function(){return $scope.refer;}, function(newval, oldval){
                if(newval){
                    $scope.data = $scope.refer;
                    if(newval.length == 0){
                        $scope.add(null);
                        $scope.addDisabled = true;
                    }
                    else{
                        $scope.addDisabled = false;
                    }
                }
            });
            $scope.add = function(item){
                $scope.data.push(item || null);
                $scope.$watch(
                    function(){
                        return $scope.data[$scope.data.length-1]
                    },
                    function(newval){
                        if(newval){
                            // protection doublons
                            if($scope.data.indexOf(newval)<$scope.data.length-1){
                                userMessages.errorMessage = "Il y a un doublon dans votre saisie !";
                                $scope.data.pop();
                            }
                            $scope.addDisabled = false;
                        }
                        else{
                            $scope.addDisabled = true;
                        }
                    }
                );
                $timeout(function(){
                    // passage du focus à la ligne créée
                    var name = $scope.schema.name+($scope.data.length-1);
                    try{
                        //cas angucomplete
                        document.getElementById(name).children[0].children[1].focus();
                    }
                    catch(e){
                        document.getElementById(name).focus();
                    }
                }, 0);
            };
            $scope.remove = function(idx){
                $scope.data.splice(idx, 1);
            };
            if($scope.refer && $scope.refer.length==0){
                $scope.add(null);
            }
            else{
            //if($scope.data && $scope.data.length>0){
                $scope.addDisabled = false;
            }
        }
    }
});


/*
 * Directive qui permet d'avoir un champ de formulaire de type fichier et qui l'envoie au serveur
 * envoie un fichier au serveur qui renvoie un identifiant de création.
 * params:
 *  fileids: la valeur source/cible du champ (liste d'identifiants)
 */
app.directive('fileinput', function(){
    return {
        restrict: 'E',
        scope: {
            fileids: '=',
            options: '='
        },
        templateUrl: 'js/templates/form/fileinput.htm',
        controller: function($scope, $rootScope, $upload, dataServ, userMessages){
            var maxSize = $scope.options.maxSize || 2048000;
            var getOptions = '';
            if($scope.options.target){
                getOptions = '?target=' + $scope.options.target;
            }
            if($scope.fileids == undefined){
                $scope.fileids = [];
            }
            $scope.delete_file = function(f_id){
                dataServ.delete('upload_file/' + f_id + getOptions, function(resp){
                    $scope.fileids.splice($scope.fileids.indexOf(resp.id), 1);
                });
            };
            $scope.$watch('upload_file', function(){
                $scope.upload($scope.upload_file);
            });
            $scope.upload = function(files){
                angular.forEach(files, function(item){
                    var ext = item.name.slice(item.name.lastIndexOf('.')+1, item.name.length);
                    if($scope.options.accepted && $scope.options.accepted.indexOf(ext)>-1){
                        if(item.size < maxSize){
                            $scope.lock = true;
                            $upload.upload({
                                url: 'upload_file' + getOptions,
                                file: item,
                                })
                                .progress(function(evt){
                                    $scope.progress = parseInt(100.0 * evt.loaded / evt.total);    
                                })
                                .success(function(data){
                                    $scope.fileids.push({fname: data.path, commentaire: ''});
                                    $scope.lock = false;
                                })
                                .error(function(data){
                                    userMessages.errorMessage = "Une erreur s'est produite durant l'envoi du fichier.";
                                    $scope.lock = false;
                                });
                        }
                        else{
                            userMessages.errorMessage = "La taille du fichier doit être inférieure à " + (maxSize/1024) + " Ko";
                        }
                    }
                    else{
                        userMessages.errorMessage = "Type d'extension refusé";
                    }
                });
            };
        }
    }
});


/**
 * Directive qui permet d'avoir un champ de formulaire de type valeur calculée modifiable
 * params: 
 *  data: la source de données du champ (une liste de références aux champs servant au calcul)
 *  refs: une liste du nom des champs à surveiller
 *  model: la source/cible du champ (eq. ng-model)
 *  modifiable: bool -> indique si le champ est modifiable ou en lecture seule
 */
app.directive('calculated', function(){
    return {
        restrict: 'E',
        scope: {
            id: "@",
            ngclass: "@",
            ngBlur: "=",
            min: '=',
            max: '=',
            data: '=',
            refs: '=',
            model: '=',
            modifiable: '=',
        },
        template: '<input id="{{id}}" ng-blur="ngBlur" class="{{ngclass}}" type="number" min="{{min}}" max="{{max}}" ng-model="model" ng-disabled="!modifiable"/>',
        controller: function($scope){
            angular.forEach($scope.refs, function(elem){
                $scope.$watch(function(){
                    return $scope.data[elem];
                }, function(newval, oldval){
                    //$scope.model += newval-oldval;
                    //if($scope.model<0) $scope.model=0;
                    $scope.model = 0;
                    angular.forEach($scope.refs, function(elem){
                        $scope.model += $scope.data[elem];
                    }, $scope);
                });
            }, $scope);
        }
    }
});


/*
 * directive pour l'affichage simple d'un formulaire
 * params: 
 *  saveurl : l'url à laquelle seront envoyées les données
 *  schemaUrl : l'url du schéma descripteur du formulaire
 *  dataurl : url pour récupérer les données en édition
 *  data : conteneur de données (complété par les données obtenues par l'url *
 */
app.directive('simpleform', function(){
    return {
        restrict: 'A',
        scope: {
            saveUrl: '=saveurl',
            schemaUrl: '=schemaurl',
            dataUrl: '=dataurl',
            data: '='
        },
        transclude: true,
        templateUrl: 'js/templates/simpleForm.htm',
        controller: function($scope, $rootScope, configServ, dataServ, userServ, userMessages, $loading, $q, SpreadSheet, $modal, $location, $timeout){
            var dirty = true;
            var editAccess = false;
            $scope.errors = {};
            $scope.currentPage = 0;
            $scope.addSubSchema = false;
            $scope.isActive = [];
            $scope.isDisabled = [];
            configServ.get('debug', function(value){
                $scope.debug = value;   
            });
            /*
             * Spinner
             * */
            $loading.start('spinner-form');
            var dfd = $q.defer();
            var promise = dfd.promise;
            promise.then(function(result) {
                $loading.finish('spinner-form');
            });

            $scope.openConfirm = function(txt){
                var modInstance = $modal.open({
                    templateUrl: 'js/templates/modalConfirm.htm',
                    resolve: {txt: function(){return txt}},
                    controller: function($modalInstance, $scope, txt){
                        $scope.txt = txt;
                        $scope.ok = function(){
                            $modalInstance.close();
                        };
                        $scope.cancel = function(){
                            $modalInstance.dismiss('cancel');
                        }
                    }
                });
                return modInstance.result;
            }
            
            
            $scope.prevPage = function(){
                if($scope.currentPage > 0){
                    $scope.isActive[$scope.currentPage] = false;
                    $scope.currentPage--;
                    $scope.isActive[$scope.currentPage] = true;
                }
            };

            $scope.nextPage = function(){
                if($scope.currentPage < $scope.isActive.length-1){
                    $scope.isActive[$scope.currentPage] = false;
                    $scope.isDisabled[$scope.currentPage] = false;
                    $scope.currentPage++;
                    $scope.isActive[$scope.currentPage] = true;
                    $scope.isDisabled[$scope.currentPage] = false;
                }
            };

            $scope.hasNext = function(idx){
                if($scope.addSubSchema){
                    return idx < $scope.isActive.length;
                }
                return idx < ($scope.isActive.length - 1);
            };

            $scope.isFormValid = function(){
                for(i=0; i<$scope.schema.groups.length; i++){
                    if($scope.Simpleform['sub_'+i]){
                        if(!$scope.Simpleform['sub_'+i].$valid){
                            return false;
                        }
                    }
                    else{
                        return false;
                    }
                }
                return true;
                //return $scope.Simpleform.$valid;
            }

            $scope.setSchema = function(resp){
                $scope.schema = angular.copy(resp);

                editAccess = userServ.checkLevel(resp.editAccess)
                
                // mise en place tabulation formulaire
                $scope.schema.groups.forEach(function(group){
                    $scope.isActive.push(false);
                    $scope.isDisabled.push(!$scope.dataUrl);
                    group.fields.forEach(function(field){
                        if(field.type=='group'){
                            field.fields.forEach(function(sub){
                                if(!sub.options){
                                    sub.options = {};
                                }
                            });

                        }
                        else{
                            if(!field.options){
                                field.options = {};
                            }
                        }
                        field.options.readOnly = !userServ.checkLevel(field.options.editLevel || 0);
                        field.options.dismissed = !userServ.checkLevel(field.options.restrictLevel || 0);
                    });
                });
                $scope.isActive[0] = true;
                $scope.isDisabled[0] = false;

                $rootScope.$broadcast('schema:init', resp);

                if($scope.dataUrl){
                    dataServ.get($scope.dataUrl, $scope.setData);
                }
                else{
                    $scope.$watch('dataUrl', function(newval){
                        if(newval){
                            dataServ.get(newval, $scope.setData);
                        }
                    });
                    if($scope.schema.subSchemaAdd && userServ.checkLevel($scope.schema.subSchemaAdd)){
                        $scope.addSubSchema = true;
                        $scope.isActive.push(false);
                    }
                    $scope.setData($scope.data || {});
                    dfd.resolve('loading form');
                }
            };

            $scope.setData = function(resp){
                if(!editAccess){
                    if($scope.schema.editAccessOverride){
                        if(!userServ.isOwner(resp[$scope.schema.editAccessOverride])){
                            dirty = false;
                            $rootScope.$broadcast('form:cancel', []);
                        }
                    }
                    else{
                        dirty = false;
                        $rootScope.$broadcast('form:cancel', []);
                    }
                }
                $scope.schema.groups.forEach(function(group){
                    group.fields.forEach(function(field){
                        if(field.type != 'group'){
                            $scope.data[field.name] = resp[field.name] != undefined ? angular.copy(resp[field.name]) : field.default != undefined ? field.default : null;
                            if(field.type=='hidden' && field.options && field.options.ref=='userId' && $scope.data[field.name]==null && userServ.checkLevel(field.options.restrictLevel || 0)){
                                $scope.data[field.name] = userServ.getUser().id_role;
                            }
                        }
                        else{
                            field.fields.forEach(function(line){
                                line.fields.forEach(function(grField){
                                    $scope.data[grField.name] = resp[grField.name] != undefined ? angular.copy(resp[grField.name]) : grField.default != undefined ? grField.default : null;
                                });
                            });
                        }

                    });
                });
                $scope.deleteAccess = userServ.checkLevel($scope.schema.deleteAccess);
                if(!$scope.deleteAccess && $scope.schema.deleteAccessOverride){
                    $scope.deleteAccess = userServ.isOwner($scope.data[$scope.schema.deleteAccessOverride]);
                }
                $rootScope.$broadcast('form:init', $scope.data);
                dfd.resolve('loading form');
            };

            $scope.cancel = function(){
                $rootScope.$broadcast('form:cancel', $scope.data);
            };


            $scope.saveConfirmed = function(){
                $loading.start('spinner-send');
                var dfd = $q.defer();
                var promise = dfd.promise;
                promise.then(function(result) {
                    $loading.finish('spinner-send');
                });
                
                if($scope.dataUrl){
                    dataServ.post($scope.saveUrl, $scope.data, $scope.updated(dfd), $scope.error(dfd));
                }
                else{
                    dataServ.put($scope.saveUrl, $scope.data, $scope.created(dfd), $scope.error(dfd));
                }
            };


            $scope.save = function(){
                var errors = null;
                if($scope.schema.subDataRef){
                    if(SpreadSheet.hasErrors[$scope.schema.subDataRef]){
                        errors = SpreadSheet.hasErrors[$scope.schema.subDataRef]();
                    }
                    else{
                        errors = null;
                    }
                    if(errors){
                        $scope.openConfirm(["Il y a des erreurs dans le sous formulaire de saisie rapide.", "Si vous confirmez l'enregistrement, les données du sous formulaire de saisie rapide ne seront pas enregistrées"]).then(function(){
                            scope.saveConfirmed();
                        },
                        function(){
                            userMessages.errorMessage = SpreadSheet.errorMessage[$scope.schema.subDataRef];
                        });
                    }
                    else{
                        $scope.saveConfirmed();
                    }
                }
                else{
                    $scope.saveConfirmed();
                }
            };

            $scope.updated = function(dfd){
                return function(resp){
                    dataServ.forceReload = true;
                    $scope.data.id = resp.id;
                    dirty = false;
                    dfd.resolve('updated');
                    $rootScope.$broadcast('form:update', $scope.data);
                };
            };

            $scope.created = function(dfd){
                return function(resp){
                    dataServ.forceReload = true;
                    $scope.data.id = resp.id;
                    dirty = false;
                    dfd.resolve('created');
                    $rootScope.$broadcast('form:create', $scope.data);
                };
            };

            $scope.error = function(dfd){
                return function(resp){
                    userMessages.errorMessage = 'Il y a des erreurs dans votre saisie';
                    $scope.errors = angular.copy(resp);
                    dfd.resolve('errors');
                }
            };

            $scope.remove = function(){
                $scope.openConfirm(["Êtes vous certain de vouloir supprimer cet élément ?"]).then(function(){
                    $loading.start('spinner-send');
                    var dfd = $q.defer();
                    var promise = dfd.promise;
                    promise.then(function(result) {
                        $loading.finish('spinner-send');
                    });
                    dataServ.delete($scope.saveUrl, $scope.removed(dfd));
                });
            };

            $scope.removed = function(dfd){
                return function(resp){
                    dirty = false;
                    dfd.resolve('removed');
                    $rootScope.$broadcast('form:delete', $scope.data);
                };
            };

            var locationBlock = $scope.$on('$locationChangeStart', function(ev, newUrl){
                if(!dirty){
                    locationBlock();
                    $location.path(newUrl.slice(newUrl.indexOf('#')+1));
                    return;
                }
                ev.preventDefault();
                $scope.openConfirm(["Etes vous certain de vouloir quitter cette page ?", "Les données non enregistrées pourraient être perdues."]).then(
                    function(){
                        locationBlock();
                        $location.path(newUrl.slice(newUrl.indexOf('#')+1));
                    }
                    );
            });

            $timeout(function(){
                configServ.getUrl($scope.schemaUrl, $scope.setSchema);
            },0);
        }
    }
});


/*
 * directive pour la gestion des données spatiales
 * params:
 *  geom -> eq. ng-model
 *  options: options à passer tel que le type de géométrie editer
 *  origin: identifiant du point à éditer
 */
app.directive('geometry', function($timeout){
    return {
        restrict: 'A',
        scope: {
            geom: '=',
            options: '=',
            origin: '=',
        },
        templateUrl:  'js/templates/form/geometry.htm',
        controller: function($scope, $rootScope, $timeout, mapService){
            $scope.editLayer = new L.FeatureGroup();

            var current = null;

            var setEditLayer = function(layer){
                mapService.getLayer().removeLayer(layer);
                $scope.updateCoords(layer);
                $scope.editLayer.addLayer(layer);
                current = layer;
            };

            var coordsDisplay = null;


            if(!$scope.options.configUrl){
                $scope.configUrl = 'js/resources/defaults.json';
            }
            else{
                $scope.configUrl = $scope.options.configUrl;
            }

            var _initialize = function(){
                mapService.initialize($scope.configUrl).then(function(){
                    mapService.getLayerControl().addOverlay($scope.editLayer, "Edition");
                    mapService.loadData($scope.options.dataUrl).then(function(){
                        if($scope.origin){
                            $timeout(function(){
                                var layer = mapService.selectItem($scope.origin);
                                if(layer){
                                    setEditLayer(layer);
                                }
                            }, 0);
                        }
                        mapService.getMap().addLayer($scope.editLayer);
                        mapService.getMap().removeLayer(mapService.getLayer());
                    });

                    $scope.controls = new L.Control.Draw({
                        edit: {featureGroup: $scope.editLayer},
                        draw: {
                            circle: false,
                            rectangle: false,
                            marker: $scope.options.geometryType == 'point',
                            polyline: $scope.options.geometryType == 'linestring',
                            polygon: $scope.options.geometryType == 'polygon',
                        },
                    });

                    mapService.getMap().addControl($scope.controls);

                    /*
                     * affichage coords curseur en edition 
                     * TODO confirmer le maintien
                     */
                    coordsDisplay = L.control({position: 'bottomleft'});
                    coordsDisplay.onAdd = function(map){
                        this._dsp = L.DomUtil.create('div', 'coords-dsp');
                        return this._dsp;
                    };
                    coordsDisplay.update = function(evt){
                        this._dsp.innerHTML = '<span>Long. : ' + evt.latlng.lng + '</span><span>Lat. : ' + evt.latlng.lat + '</span>';
                    };

                    mapService.getMap().on('mousemove', function(e){
                        coordsDisplay.update(e);
                    });

                    coordsDisplay.addTo(mapService.getMap());
                    /*
                     * ---------------------------------------
                     */


                    mapService.getMap().on('draw:created', function(e){
                        if(!current){
                            $scope.editLayer.addLayer(e.layer);
                            current = e.layer;
                            $rootScope.$apply($scope.updateCoords(current));
                        }
                    });

                    mapService.getMap().on('draw:edited', function(e){
                        $rootScope.$apply($scope.updateCoords(e.layers.getLayers()[0]));
                    });

                    mapService.getMap().on('draw:deleted', function(e){
                        current = null;
                        $rootScope.$apply($scope.updateCoords(current));
                    });
                    $timeout(function() {
                        mapService.getMap().invalidateSize();
                    }, 0 );
                
                });
            };

            var initialize = function(){
                try{
                    _initialize();
                }
                catch(e){
                    $scope.$watch(function(){ return mapService.initialize }, function(newval){
                        if(newval){
                            _initialize();
                        }
                    });
                }
            }

            // initialisation de la carte
            $timeout(initialize, 0);

            $scope.geom = $scope.geom || [];

            $scope.updateCoords = function(layer){
                $scope.geom.splice(0);
                if(layer){
                    try{
                        layer.getLatLngs().forEach(function(point){
                            $scope.geom.push([point.lng, point.lat]);
                        });
                    }
                    catch(e){
                        point = layer.getLatLng();
                        $scope.geom.push([point.lng, point.lat]);
                    }
                }
            };
        },
    };
});

/*
 * datepicker
 * params:
 *  uid: id du champ
 *  date: valeur initiale format yyyy-MM-dd
 */
app.directive('datepick', function(){
    return{
        restrict:'A',
        scope: {
            uid: '@',
            date: '=',
            ngrequired: '=',
        },
        templateUrl: 'js/templates/form/datepick.htm',
        controller: function($scope){
            $scope.opened = false;
            $scope.toggle = function($event){
                $event.preventDefault();
                $event.stopPropagation();
                $scope.opened = !$scope.opened;
            };

            if($scope.date && $scope.date.getDate){
                $scope.date = ('00'+$scope.date.getDate()).slice(-2) + '/' + ('00' + ($scope.date.getMonth()+1)).slice(-2) + '/' + $scope.date.getFullYear();
            }

            $scope.$watch('date', function(newval){
                try{
                    newval.setHours(12);
                    $scope.date = newval;
                }
                catch(e){
                    if(newval){
                        try{
                            $scope.date = newval;
                        }
                        catch(e){
                            //$scope.date = $scope.date.replace(/(\d+)-(\d+)-(\d+)/, '$3/$2/$1');
                        }
                    }
                }
            });
        }
    }
});


app.factory('SpreadSheet', function(){
    return {
        errorMessage: {},
        hasErrors: {},
    };
});

/**
 * Directive pour l'affichage d'un tableau de saisie rapide style feuille de calcul
 * params : 
 *  schemaurl -> url du schema descripteur du tableau
 *  data -> reference vers le dictionnaire de données du formulaire parent
 *  dataref -> champ à utiliser pour stocker les données
 *  subtitle -> Titre indicatif du formulaire
 */
app.directive('spreadsheet', function(){
    return {
        restrict: 'A',
        scope: {
            schemaUrl: '=schemaurl',
            dataRef: '=dataref',
            subTitle: '=subtitle',
            dataIn: '=data',
        },
        templateUrl: 'js/templates/form/spreadsheet.htm',
        controller: function($scope, configServ, userServ, SpreadSheet, ngTableParams){
            var defaultLine = {};
            var lines = [];
            $scope.data = [];
            $scope.$watch(
                function(){
                    return $scope.schemaUrl;
                }, 
                function(newval){
                    if(newval){
                        configServ.getUrl(newval, $scope.setSchema);
                    }
                }
            );
            $scope.setSchema = function(schema){
                $scope.schema = schema;
                $scope.schema.fields.forEach(function(item){
                    defaultLine[item.name] = item.default || null;
                });
                $scope.data = lines;
                $scope.addLines();
            };

            $scope.addLines = function(){
                for(i=0; i<3; i++){
                    line = angular.copy(defaultLine);
                    lines.push(line);
                }
            };

            $scope.tableParams = new ngTableParams({},
                {
                    getData: function($defer, params){
                        return $scope.data;
                    }
                }
            );

            $scope.check = function(){
                var out = [];
                var err_lines = [];
                var primaries = [];
                var errMsg = "Erreur";
                var hasErrors = false;
                $scope.data.forEach(function(line){
                    var line_valid = true;
                    var line_empty = true;
                    $scope.schema.fields.forEach(function(field){
                        if(field.type == "hidden"){
                            if(field.options && field.options.ref == 'userId' && line[field.name] == null){
                                /*
                                 * ajout du numérisateur à la ligne
                                 */
                                line[field.name] = userServ.getUser().id_role;
                            }
                        }
                        else{
                            if(line[field.name] && line[field.name] != null){
                                line_empty = false;
                            }
                            if((field.options.required || field.options.primary) && (!line[field.name] || line[field.name] == null)){
                                line_valid = false;
                            }
                            if(field.options.primary && line_valid){
                                /*
                                 * gestion des clés primaires pour la suppression des doublons
                                 */
                                if(primaries.indexOf(line[field.name])>-1){
                                    line_valid = false;
                                    errMsg = "Doublon";
                                    hasErrors = true
                                }
                                else{
                                    primaries.push(line[field.name]);
                                }
                            }
                        }
                    });
                    if(line_valid){
                        out.push(line);
                    }
                    else{
                        if(!line_empty){
                            err_lines.push($scope.data.indexOf(line) + 1);
                            hasErrors = true;
                        }
                    }
                });


                if(!$scope.dataIn[$scope.dataRef]){
                    $scope.dataIn[$scope.dataRef] = [];
                }
                else{
                    $scope.dataIn[$scope.dataRef].splice(0);
                }
                out.forEach(function(item){
                    $scope.dataIn[$scope.dataRef].push(item);
                });
                if(hasErrors){
                    errMsg = 'Il y a des erreurs ligne(s) : '+err_lines.join(', ');
                    SpreadSheet.errorMessage[$scope.dataRef]= errMsg;
                }
                return hasErrors;
            };
            SpreadSheet.hasErrors[$scope.dataRef] = $scope.check;
        },
    };
});

app.directive('subeditform', function(){
    return{
        restrict: 'A',
        scope: {
            schema: "=",
            saveUrl: "=saveurl",
            refId: "=refid",
        },
    template: '<div spreadsheet schemaurl="schema" dataref="dataRef" data="data" subtitle=""></div><div style="margin-top: 5px;"><button type="button" class="btn btn-success float-right" ng-click="save()">Enregistrer</button></div>',
        controller: function($scope, $rootScope, dataServ, configServ, SpreadSheet, userMessages, userServ, $loading, $q){
            $scope.data = {refId: $scope.refId};
            $scope.dataRef = '__items__';

            $scope.save = function(){
                errors = SpreadSheet.hasErrors[$scope.dataRef]();
                if(errors){
                    userMessages.errorMessage = SpreadSheet.errorMessage[$scope.dataRef];
                }
                else{
                    /*
                     * Spinner
                     * */
                    $loading.start('spinner-detail');
                    var dfd = $q.defer();
                    var promise = dfd.promise;
                    promise.then(function(result) {
                        $loading.finish('spinner-detail');
                    });
                    dataServ.put($scope.saveUrl, $scope.data, $scope.saved(dfd), $scope.error(dfd));
                }
            };

            $scope.saved = function(deferred){
                return function(resp){
                    resp.ids.forEach(function(item, key){
                        $scope.data.__items__[key].id = item;
                    });
                    deferred.resolve();
                    userMessages.successMessage = "Données ajoutées";
                    $rootScope.$broadcast('subEdit:dataAdded', $scope.data.__items__);
                };
            };

            $scope.error = function(deferred){
                var _errmsg = ''
                return function(resp){
                    deferred.resolve();
                    for(errkey in resp){
                        _errmsg += resp[errkey];
                    }
                    userMessages.errorMessage = _errmsg;
                };
            };
        }
    };
});

app.directive('multisel', function(){
    return {
        restrict: 'E',
        templateUrl: 'js/templates/form/multisel.htm',
        scope: {
            schema: '=',
            data: '=',
        },
        controller: function($scope){
            console.log('multisel');
            $scope.$watch('schema', function(nv, ov){
                console.log($scope.schema);
            });
            if(!$scope.data){
                $scope.data = [];
            }
            if(!$scope.data.push){
                //données anciennes
                $scope.data = [$scope.data];
            }
            $scope.tmp_data = {};

            $scope.$watch('data', function(nv, ov){
                if(nv !== undefined){
                    if(nv === null ){
                        $scope.data = [];
                    }
                    if(!nv.push){
                        $scope.data = [nv];
                    }
                    try{
                        $scope.data.forEach(function(value){
                            $scope.tmp_data[value] = true;
                        });
                    }
                    catch(e){

                    }
                }
            });
            $scope.update_values = function(){
                for(key in $scope.tmp_data){
                    key = parseInt(key);
                    if($scope.tmp_data[key]){
                        if($scope.data.indexOf(key) === -1){
                            $scope.data.push(key);
                        }
                    }
                    else{
                        var idx = $scope.data.indexOf(key);
                        if( idx !== -1){
                            $scope.data.splice(idx, 1);
                        }                        
                    }
                }
            }
        }
    };
});
