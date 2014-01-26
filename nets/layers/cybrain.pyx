'''
Created on Jan 17, 2014

@author: Cristian
'''

#TODO: class LayerConnection, class FullConnection(LayerConnections), Layer.getConnections, flag propagate for fowardInput, backwardErrorDerivative, etc.

cdef class Neuron(object):
    cdef:
        public bint is_input
        public bint is_output
        public list incoming_connections
        public list outgoing_connections
        public int incoming_connection_count
        public int outgoing_connection_count
        public int forward_counter
        public int backward_counter
        public float weighted_sum
        public float activation_state
        public float error_diff
        public float local_gradient
        public Layer layer       
    
    def __init__(self, bint is_input = False, bint is_output = False):
        if is_input and is_output:
            raise ValueError("Neuron can't be input and output")
        
        self.is_input = is_input
        self.is_output = is_output
        
        self.outgoing_connections = []
        self.incoming_connections = []
        
        self.incoming_connection_count = 0
        self.outgoing_connection_count = 0
        
        
        
        self.forward_counter = 0
        self.backward_counter = 0
        
        self.weighted_sum = 0.0
        self.activation_state = 0.0
        self.error_diff = 0.0
        self.local_gradient = 0.0
        
    def addIncomingConnection(self, Connection connection):
        self.incoming_connections.append(connection)
        self.incoming_connection_count += 1
        
    def addOutgoingConnection(self, Connection connection):
        self.outgoing_connections.append(connection)
        self.outgoing_connection_count += 1
        
        
    cdef public receiveSignal(self, float signal):
        self.weighted_sum += signal
        self.forward_counter += 1

        if self.incoming_connection_count > self.forward_counter:
            raise ValueError('Cycle Detected')

        if self.incoming_connection_count == self.forward_counter:
            self.propagateForward()

        
    cdef float activationFunction(self, float weighted_sum ):
        return weighted_sum
            
    cpdef propagateForward(self):
        self.activation_state = self.activationFunction(self.weighted_sum)
        
        cdef Connection connection
        for connection in self.outgoing_connections:
            connection.forwardSignal( self.activation_state )
            
    cdef public receiveErrorSignal(self, float some_local_gradient, float learning_rate  ):
        self.error_diff += some_local_gradient
        self.backward_counter += 1
        if self.outgoing_connection_count > self.backward_counter:
            raise ValueError('Cycle Detected')
        if self.outgoing_connection_count == self.backward_counter:
            self.propagateErrorBackwards( learning_rate )


    cdef float activationFunctionDerivative(self, float weighted_sum ):
        """
        dy/dz where : y = f(z)
        """
        return 1.0

    cpdef propagateErrorBackwards(self, float learning_rate ):
        self.local_gradient = self.error_diff * self.activationFunctionDerivative(self.weighted_sum)

        cdef Connection connection
        for connection in self.incoming_connections:
            connection.backwardErrorSignal( self.local_gradient, learning_rate )

    cpdef float outputError(self, float target):
        return 0.5*( target - self.activation_state )**2

    cpdef errorDerivative(self, float target):
        self.error_diff = self.activation_state - target


    def clearAcumulators(self):
        self.error_diff = 0.0
        self.weighted_sum = 0.0

    def clearCounters(self):
        self.forward_counter = 0
        self.backward_counter = 0

    def __repr__(self):
        return "{}".format(self.activation_state)


cdef class LinearNeuron(Neuron):

    def __init__(self, is_input = False, is_output = False):
        Neuron.__init__(self, is_input, is_output)


import random as rn

cdef class Connection(object):
    """
    Connection base class
    """
    cdef:
        public Neuron source
        public Neuron destination
        public float weight
        public float weight_diff


    def __init__(self, Neuron source, Neuron destination, float weight = 0.0):
        self.source = source
        source.addOutgoingConnection( self )

        self.destination = destination
        destination.addIncomingConnection( self )

        self.weight = weight if weight else rn.uniform(-1,1)
        self.weight_diff = 0.0

    cdef public forwardSignal(self, float signal):
        self.fowardPropagation( self.weight * signal )

    def fowardPropagation(self, float signal):
        self.destination.receiveSignal( signal )

    def backwardErrorSignal( self, float local_gradient, float learning_rate ):
        self.weight_diff += local_gradient * self.source.activation_state
        self.backwardErrorPropagation( local_gradient, learning_rate )

    def backwardErrorPropagation(self, float local_gradient, float learning_rate):
        self.source.receiveErrorSignal( local_gradient, learning_rate )

    def clear(self):
        self.weight_diff = 0.0

    def __repr__(self):
        return "source: {}, destination: {}, weight: {}".format(self.source, self.destination, self.weight)

class LinearConnection(Connection):

    def __init__(self, Neuron source, Neuron destination, float weight = 0.0):
        Connection.__init__(self, source, destination, weight)




cdef class Layer(object):
    cdef:
        public list neurons

    def __init__(self, list neurons = list() ):
        self.neurons = []
        if neurons:
            self.addNeurons( neurons )

    cpdef addNeurons( self, list neurons ):
        cdef Neuron neuron
        for neuron in neurons:
            self.neurons.append(neuron)
            neuron.layer = self

    cpdef addNeuron( self, Neuron neuron ):
        self.neurons.append( neuron )
        neuron.layer = self

    cpdef fowardPropagation(self):
        cdef:
            Neuron neuron

        for neuron in self.neurons:
            neuron.propagateForward()

    cpdef forwpropagateInput(self, list input_list):
        cdef:
            Neuron neuron
            int i, N

        N = len(input_list)
        if len(self.neurons) != N:
            raise ValueError("target list and neuron list don't have the same lenght")

        for i in range(N):
            neuron = self.neurons[i]
            neuron.weighted_sum = input_list[i]
            neuron.propagateForward()

    cpdef backwardErrorPropagation(self, float learing_rate ):
        cdef:
            Neuron neuron

        for neuron in self.neurons:
            neuron.propagateErrorBackwards( learing_rate )

    cpdef calculateErrorDerivative(self, list target):
        cdef:
            Neuron neuron
            int i, N

        N = len(target)
        if len(self.neurons) != N:
            raise ValueError("target list and neuron list don't have the same lenght")

        for i in range(N):
            self.neurons[i].errorDerivative(target[i])

    cpdef backpropagateError(self, list targets, bint learning_rate):
        cdef:
            Neuron neuron
            int i, N
            float target

        N = len(targets)
        if len(self.neurons) != N:
            raise ValueError("target list and neuron list don't have the same lenght")

        for i in range(N):
            neuron = self.neurons[i]
            target = targets[i]
            neuron.errorDerivative(target)
            neuron.propagateErrorBackwards( learning_rate )
        
        
    def __repr__(self):
        cdef: 
            Neuron neuron
            
        s = ""
        
        for neuron in self.neurons:
            s += neuron.__repr__() + ", "
            
        return s
    
    
    
    
    